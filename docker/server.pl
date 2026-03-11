#!/usr/bin/perl
# server.pl — Testmaker HTTP server
#
# Serves the quiz engine and handles PDF/TXT parsing requests.
#
# Routes:
#   GET  /            -> quiz-engine.html
#   GET  /sample      -> examples/sample-questions.json
#   GET  /schema      -> schemas/questions.schema.json
#   POST /parse       -> run extract-questions.pl on uploaded file, return JSON
#   GET  /health      -> 200 OK (for container health checks)
#
# Request format for POST /parse:
#   Content-Type: application/pdf  (or text/plain)
#   X-Filename:   original-filename.pdf   (used to set --name)
#   Body:         raw file bytes

use strict;
use warnings;
use IO::Socket::INET;
use File::Temp qw(tempfile);
use File::Basename qw(basename);
use POSIX qw(WNOHANG);

my $PORT    = $ENV{PORT}    // 8080;
my $APP_DIR = $ENV{APP_DIR} // '/app';

my $PARSER  = "$APP_DIR/parsers/extract-questions.pl";
my $ENGINE  = "$APP_DIR/engine/quiz-engine.html";
my $SAMPLE  = "$APP_DIR/examples/sample-questions.json";
my $SCHEMA  = "$APP_DIR/schemas/questions.schema.json";

die "Parser not found: $PARSER\n" unless -f $PARSER;
die "Engine not found: $ENGINE\n" unless -f $ENGINE;

# ── Server socket ──────────────────────────────────────────────────────────────

my $server = IO::Socket::INET->new(
    LocalPort => $PORT,
    Type      => SOCK_STREAM,
    Reuse     => 1,
    Listen    => 10,
) or die "Cannot bind to port $PORT: $!\n";

print "Testmaker running at http://localhost:$PORT\n";
print "Drop a PDF onto the page to extract questions.\n";

# Reap zombie child processes
$SIG{CHLD} = sub { while (waitpid(-1, WNOHANG) > 0) {} };

# ── Accept loop ────────────────────────────────────────────────────────────────

while (my $client = $server->accept()) {
    my $pid = fork();
    if (!defined $pid) {
        warn "fork failed: $!\n";
        close $client;
        next;
    }
    if ($pid == 0) {
        # Child: handle the request, then exit
        $server->close();
        handle_request($client);
        close $client;
        exit 0;
    }
    # Parent: close client socket and loop
    close $client;
}

# ── Request handler ────────────────────────────────────────────────────────────

sub handle_request {
    my ($client) = @_;

    # Read request headers (stop at blank line)
    my %headers;
    my $request_line = '';
    my $bytes_read   = 0;

    while (my $line = readline_crlf($client)) {
        last if $line eq '';           # blank line = end of headers
        if (!$request_line) {
            $request_line = $line;
        } else {
            if ($line =~ /^([^:]+):\s*(.*)/) {
                $headers{lc($1)} = $2;
            }
        }
    }

    return unless $request_line;

    my ($method, $path, $proto) = split /\s+/, $request_line, 3;
    $path =~ s/[?#].*//;   # strip query string / fragment

    # ── Route ──────────────────────────────────────────────────────────────────

    if ($method eq 'GET' && $path eq '/') {
        serve_file($client, $ENGINE, 'text/html; charset=utf-8');

    } elsif ($method eq 'GET' && $path eq '/sample') {
        serve_file($client, $SAMPLE, 'application/json; charset=utf-8');

    } elsif ($method eq 'GET' && $path eq '/schema') {
        serve_file($client, $SCHEMA, 'application/json; charset=utf-8');

    } elsif ($method eq 'GET' && $path eq '/health') {
        send_response($client, 200, 'text/plain', "OK\n");

    } elsif ($method eq 'POST' && $path eq '/parse') {
        handle_parse($client, \%headers);

    } else {
        send_response($client, 404, 'text/plain', "Not found: $path\n");
    }
}

# ── /parse handler ─────────────────────────────────────────────────────────────

sub handle_parse {
    my ($client, $headers) = @_;

    my $content_length = $headers->{'content-length'} // 0;
    my $content_type   = $headers->{'content-type'}   // 'application/octet-stream';
    my $x_filename     = $headers->{'x-filename'}     // 'upload.pdf';

    # Determine file extension from Content-Type or X-Filename
    my $ext;
    if    ($content_type =~ /pdf/)       { $ext = 'pdf'  }
    elsif ($content_type =~ /plain/)     { $ext = 'txt'  }
    elsif ($content_type =~ /html/)      { $ext = 'html' }
    elsif ($x_filename   =~ /\.(\w+)$/) { $ext = lc($1) }
    else                                 { $ext = 'pdf'  }

    unless ($ext =~ /^(pdf|txt|html?)$/) {
        send_json_error($client, 400, "Unsupported file type: $ext. Use .pdf, .txt, or .html");
        return;
    }

    # Read request body
    if ($content_length <= 0) {
        send_json_error($client, 400, "No file data received (Content-Length is 0).");
        return;
    }
    if ($content_length > 50 * 1024 * 1024) {   # 50 MB limit
        send_json_error($client, 413, "File too large (max 50 MB).");
        return;
    }

    my $body = '';
    my $remaining = $content_length;
    while ($remaining > 0) {
        my $chunk;
        my $n = read($client, $chunk, ($remaining > 65536 ? 65536 : $remaining));
        last unless defined $n && $n > 0;
        $body .= $chunk;
        $remaining -= $n;
    }

    if (length($body) == 0) {
        send_json_error($client, 400, "Received empty file.");
        return;
    }

    # Write to temp file
    my ($tmp_fh, $tmp_path) = tempfile(SUFFIX => ".$ext", UNLINK => 1);
    binmode $tmp_fh;
    print $tmp_fh $body;
    close $tmp_fh;

    # Derive a display name from X-Filename
    my $name = basename($x_filename);
    $name =~ s/\.[^.]+$//;      # strip extension
    $name =~ s/[-_]/ /g;
    $name =~ s/\b(\w)/uc($1)/ge;

    # Write parser output to a temp JSON file
    my ($out_fh, $out_path) = tempfile(SUFFIX => '.json', UNLINK => 1);
    close $out_fh;

    # Run the parser (capture stderr for diagnostics)
    my $escaped_in  = $tmp_path;
    my $escaped_out = $out_path;
    # Simple escaping: wrap in single quotes (safe inside Alpine container)
    $escaped_in  =~ s/'/'\\''/g;
    $escaped_out =~ s/'/'\\''/g;
    $name        =~ s/'/'\\''/g;

    my $cmd    = "perl '$PARSER' '$escaped_in' -o '$escaped_out' -n '$name' 2>&1";
    my $stderr = `$cmd`;
    my $exit   = $?;

    unlink $tmp_path;

    if ($exit != 0) {
        unlink $out_path;
        send_json_error($client, 500, "Parser failed: $stderr");
        return;
    }

    # Read the output JSON
    unless (-s $out_path) {
        unlink $out_path;
        send_json_error($client, 500, "Parser produced no output. Check that the document contains numbered questions.");
        return;
    }

    open(my $json_fh, '<:raw', $out_path) or do {
        unlink $out_path;
        send_json_error($client, 500, "Could not read parser output: $!");
        return;
    };
    local $/;
    my $json_body = <$json_fh>;
    close $json_fh;
    unlink $out_path;

    # Include stderr warnings as a response header so the UI can surface them
    my $warnings = ($stderr =~ /\[REVIEW\]/) ? 'true' : 'false';
    my $review_count = () = $stderr =~ /\[REVIEW\]/g;

    my $extra_headers = "X-Parse-Warnings: $warnings\r\n"
                      . "X-Review-Count: $review_count\r\n";

    send_response($client, 200, 'application/json; charset=utf-8', $json_body, $extra_headers);
}

# ── Helpers ────────────────────────────────────────────────────────────────────

sub serve_file {
    my ($client, $path, $mime) = @_;
    unless (-f $path) {
        send_response($client, 404, 'text/plain', "File not found: $path\n");
        return;
    }
    open(my $fh, '<:raw', $path) or do {
        send_response($client, 500, 'text/plain', "Cannot read file: $!\n");
        return;
    };
    local $/;
    my $body = <$fh>;
    close $fh;
    send_response($client, 200, $mime, $body);
}

sub send_json_error {
    my ($client, $status, $msg) = @_;
    $msg =~ s/"/\\"/g;
    send_response($client, $status, 'application/json; charset=utf-8',
        "{\"error\":\"$msg\"}\n");
}

sub send_response {
    my ($client, $status, $mime, $body, $extra_headers) = @_;
    $extra_headers //= '';
    my $len = length($body);
    my $status_text = {
        200 => 'OK', 400 => 'Bad Request', 404 => 'Not Found',
        413 => 'Payload Too Large', 500 => 'Internal Server Error',
    }->{$status} // 'Unknown';

    print $client "HTTP/1.1 $status $status_text\r\n"
                . "Content-Type: $mime\r\n"
                . "Content-Length: $len\r\n"
                . "Connection: close\r\n"
                . "Access-Control-Allow-Origin: *\r\n"
                . $extra_headers
                . "\r\n"
                . $body;
}

# Read a CRLF-terminated line from a socket, return with CRLF stripped
sub readline_crlf {
    my ($sock) = @_;
    my $line = '';
    while (1) {
        my $ch;
        my $n = read($sock, $ch, 1);
        return undef unless defined $n && $n > 0;
        $line .= $ch;
        if ($line =~ s/\r\n$//) { return $line }
        if (length($line) > 8192) { return substr($line, 0, 8192) }  # guard
    }
}
