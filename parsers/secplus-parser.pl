#!/usr/bin/perl
# secplus-parser.pl — SecurityTester reference parser (adapted for Testmaker)
#
# Parses the Security+ SY0-701 source text file (secplus.txt) produced by
# pdftotext and outputs a valid Testmaker questions.json file.
#
# This is a document-specific parser: line ranges are hard-coded to the
# exact structure of "CompTIA Security+ Practice Tests: Exam SY0-701, 3rd Ed."
# (Seidl, Sybex, 2024). It is kept here as a reference for how to write a
# parser for a known, fixed-format document.
#
# For unknown documents use extract-questions.pl instead.
#
# USAGE
#   perl secplus-parser.pl [OPTIONS]
#
# OPTIONS
#   -f, --file FILE     Path to secplus.txt  (default: ./secplus.txt)
#   -o, --output FILE   Write JSON to FILE   (default: stdout)
#   -h, --help          Show this help message

use strict;
use warnings;
use JSON;
use Getopt::Long qw(:config no_ignore_case bundling);
use File::Basename;

# ── CLI ───────────────────────────────────────────────────────────────────────

my ($opt_file, $opt_output, $opt_help);
GetOptions(
    'file|f=s'   => \$opt_file,
    'output|o=s' => \$opt_output,
    'help|h'     => \$opt_help,
) or die "Error in arguments. Run with --help for usage.\n";

if ($opt_help) {
    show_help();
    exit 0;
}

my $infile = $opt_file // 'secplus.txt';
die "File not found: $infile\n  Use -f to specify the path to secplus.txt\n"
    unless -e $infile;

# ── Hard-coded structure of the source document ───────────────────────────────
# Line ranges are 1-indexed. Questions and answers are in separate sections.

my @Q_RANGES = (
    [359,  683],    # Chapter 1 — Domain 1.0
    [684,  1095],   # Chapter 2 — Domain 2.0
    [1096, 1628],   # Chapter 3 — Domain 3.0
    [1629, 2157],   # Chapter 4 — Domain 4.0
    [2158, 2585],   # Chapter 5 — Domain 5.0
);

my @A_RANGES = (
    [2595, 2824],   # Chapter 1
    [2825, 3124],   # Chapter 2
    [3125, 3497],   # Chapter 3
    [3498, 3844],   # Chapter 4
    [3845, 4485],   # Chapter 5
);

my @DOMAIN_NAMES = (
    'Domain 1.0: General Security Concepts',
    'Domain 2.0: Threats, Vulnerabilities, and Mitigations',
    'Domain 3.0: Security Architecture',
    'Domain 4.0: Security Operations',
    'Domain 5.0: Security Program Management and Oversight',
);

my @DOMAIN_WEIGHTS = (12, 22, 18, 28, 20);  # CompTIA exam weights (%)

# ── Load source file ──────────────────────────────────────────────────────────

open(my $fh, '<', $infile) or die "Cannot open $infile: $!\n";
my @raw_lines = <$fh>;
close $fh;

for my $line (@raw_lines) {
    chomp $line;
    $line =~ s/\r$//;
    $line =~ s/^\x0C//;      # form-feed at start of page (PDF artifact)
    $line =~ s/\x{ad}//g;    # soft hyphen
}

printf STDERR "Loaded %d lines from %s\n", scalar @raw_lines, $infile;

# ── Parse all chapters ────────────────────────────────────────────────────────

my @all_questions;
my $total_warnings = 0;

for my $ch (1..5) {
    my ($qs, $qe) = @{ $Q_RANGES[$ch-1] };
    my ($as, $ae) = @{ $A_RANGES[$ch-1] };

    printf STDERR "Parsing Chapter %d...\n", $ch;

    my @questions = parse_questions($ch, $qs, $qe);
    my %answers   = parse_answers($ch, $as, $ae);

    my $matched = 0;
    for my $q (@questions) {
        my $num = $q->{_number};
        if (exists $answers{$num}) {
            $q->{correct}     = $answers{$num}{letter};
            $q->{explanation} = $answers{$num}{explanation};
            $matched++;
        } else {
            warn "  [WARN] No answer for Chapter $ch Q$num\n";
            $total_warnings++;
            $q->{correct}     = '';
            $q->{explanation} = '';
        }

        # Remove internal tracking field before output
        delete $q->{_number};

        push @all_questions, $q;
    }

    printf STDERR "  Questions: %d | Answers: %d | Matched: %d\n",
        scalar @questions, scalar keys %answers, $matched;
}

printf STDERR "\nTotal questions: %d  |  Warnings: %d\n",
    scalar @all_questions, $total_warnings;

# ── Build Testmaker output ────────────────────────────────────────────────────

my @categories;
for my $i (0..4) {
    push @categories, {
        id     => $i + 1,
        name   => $DOMAIN_NAMES[$i],
        weight => $DOMAIN_WEIGHTS[$i],
    };
}

my %output = (
    meta => {
        name        => 'CompTIA Security+ SY0-701 Practice Tests',
        description => 'Practice questions for CompTIA Security+ exam SY0-701.',
        version     => '1.0',
        author      => 'David Seidl (Sybex, 2024)',
        examInfo    => {
            questionCount  => 90,
            timeMinutes    => 90,
            passingPercent => 75,
        },
        categories => \@categories,
    },
    questions => \@all_questions,
);

my $json = JSON->new->utf8->pretty->encode(\%output);

if ($opt_output) {
    open(my $out, '>:utf8', $opt_output) or die "Cannot write $opt_output: $!\n";
    print $out $json;
    close $out;
    printf STDERR "Written: %s\n", $opt_output;
} else {
    binmode STDOUT, ':utf8';
    print $json;
}

exit 0;

# =============================================================================
# PARSERS
# =============================================================================

# Return lines for a 1-indexed inclusive range
sub get_lines {
    my ($start, $end) = @_;
    return map { $raw_lines[$_-1] } ($start..$end);
}

# Parse questions from one chapter's section
# Returns list of partial question hashrefs (no correct/explanation yet)
sub parse_questions {
    my ($chapter, $start, $end) = @_;
    my @lines = get_lines($start, $end);

    my @questions;
    my $current_num  = 0;
    my @block_lines;

    my $flush = sub {
        return unless $current_num > 0 && @block_lines;
        my $text = join(' ', @block_lines);
        my $q = parse_question_block($chapter, $current_num, $text);
        push @questions, $q if $q;
    };

    for my $line (@lines) {
        # Skip blank lines, bare page numbers, and document-specific headers
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*\d+\s*$/;            # bare page number
        next if $line =~ /^Chapter \d+\s+Domain/;
        next if $line =~ /^THE COMPTIA/;
        next if $line =~ /^ Domain \d+\.\d+/;
        next if $line =~ /^ \d+\.\d+ /;

        # New question: starts with a number (period optional)
        if ($line =~ /^(\d+)\.?\s+[A-Z]/) {
            $flush->();
            $current_num  = $1 + 0;
            @block_lines  = ($line);
        } elsif ($current_num > 0) {
            push @block_lines, $line;
        }
    }
    $flush->();

    return @questions;
}

# Parse a collected text block into a question hashref
sub parse_question_block {
    my ($chapter, $num, $text) = @_;

    # Strip leading question number
    $text =~ s/^\d+\.?\s+//;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+|\s+$//g;

    # Greedy first group captures question text; lazy groups capture options.
    # The greedy (.+) correctly handles incidental "A." within the question.
    if ($text =~ /^(.+)\s+A\.\s+(.+?)\s+B\.\s+(.+?)\s+C\.\s+(.+?)\s+D\.\s+(.+)$/) {
        my ($q, $a, $b, $c, $d) = ($1, $2, $3, $4, $5);

        # Clean up PDF hyphenation artifacts: "Full-d isk" -> "Full-disk"
        for my $s ($q, $a, $b, $c, $d) {
            $s =~ s/([a-z])-\s+([a-z])/$1$2/g;
            $s =~ s/\s+$//;
        }

        return {
            _number  => $num,           # internal; removed before output
            id       => "ch${chapter}_q${num}",
            category => $chapter + 0,
            question => $q,
            options  => { A => $a, B => $b, C => $c, D => $d },
        };
    }

    warn "  [WARN] Could not parse Ch$chapter Q$num: " . substr($text, 0, 80) . "...\n";
    $total_warnings++;
    return undef;
}

# Parse answers for one chapter's answer section
# Returns: %answers = ( question_number => { letter => 'B', explanation => '...' } )
sub parse_answers {
    my ($chapter, $start, $end) = @_;
    my @lines = get_lines($start, $end);

    my %answers;
    my $current_num    = 0;
    my $current_letter = '';
    my @block_lines;

    my $flush = sub {
        return unless $current_num > 0;
        my $exp = join(' ', @block_lines);
        $exp =~ s/\s+/ /g;
        $exp =~ s/^\s+|\s+$//g;
        $exp =~ s/([a-z])-\s+([a-z])/$1$2/g;
        $answers{$current_num} = { letter => $current_letter, explanation => $exp };
    };

    for my $line (@lines) {
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*\d+\s*$/;
        next if $line =~ /^Chapter \d+: Domain/;
        next if $line =~ /^Appendix\s+Answers to Review/;
        next if $line =~ /^Appendix$/;
        next if $line =~ /^Answers to Review Questions$/;

        # "N. A. explanation text" — space after letter is optional in some entries
        if ($line =~ /^(\d+)\.\s+([A-D])\.\s*(.+)/) {
            my ($num, $letter, $rest) = ($1 + 0, $2, $3);
            $flush->();
            $current_num    = $num;
            $current_letter = $letter;
            @block_lines    = ($rest);
            next;
        }

        push @block_lines, $line if $current_num > 0;
    }
    $flush->();

    return %answers;
}

# =============================================================================
# HELP
# =============================================================================

sub show_help {
    print <<'HELP';
secplus-parser.pl — Security+ SY0-701 source parser (Testmaker reference parser)

Parses the secplus.txt file produced by pdftotext from:
  "CompTIA Security+ Practice Tests: Exam SY0-701, 3rd Ed." (Seidl, Sybex 2024)

Outputs a Testmaker-compatible questions.json with all 1,005 questions.

USAGE
    perl secplus-parser.pl [OPTIONS]

OPTIONS
    -f, --file FILE     Path to secplus.txt  (default: ./secplus.txt)
    -o, --output FILE   Write JSON to FILE   (default: stdout)
    -h, --help          Show this help message

EXAMPLES
    perl secplus-parser.pl -f /c/Code/SecurityTester/secplus.txt -o questions.json
    perl secplus-parser.pl --file secplus.txt --output secplus-questions.json

NOTE
    This parser is document-specific — the line ranges are hard-coded to the
    exact page layout of the source book. It is provided as a reference for
    how to write a purpose-built parser for a known, fixed-format document.

    For arbitrary documents use extract-questions.pl instead.

HELP
}
