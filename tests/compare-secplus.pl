#!/usr/bin/perl
# compare-secplus.pl — Phase 5 comparison tool
#
# Runs both the general (extract-questions.pl) and the purpose-built
# (secplus-parser.pl) parsers against the Seidl Security+ source text,
# then compares the results against the SecurityTester reference questions.json.
#
# PURPOSE
#   This test shows the real-world capability of the general heuristic parser
#   vs a document-specific parser on the same input, and confirms the
#   secplus-parser.pl still produces output matching the SecurityTester set.
#
#   NOTE: The Seidl content is copyrighted. No parsed questions are committed
#   to this repo. This script runs locally and reports stats only.
#
# USAGE
#   perl tests/compare-secplus.pl [--secplus-txt PATH] [--reference PATH]
#
# OPTIONS
#   --secplus-txt PATH   Path to secplus.txt  (default: C:/Code/SecurityTester/secplus.txt)
#   --reference PATH     Path to SecurityTester questions.json
#                        (default: C:/Code/SecurityTester/questions.json)
#   -h, --help           Show this help

use strict;
use warnings;
use JSON;
use Getopt::Long qw(:config no_ignore_case bundling);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my ($opt_txt, $opt_ref, $opt_help);
GetOptions(
    'secplus-txt=s' => \$opt_txt,
    'reference=s'   => \$opt_ref,
    'help|h'        => \$opt_help,
) or die "Bad arguments. Run with --help.\n";

if ($opt_help) {
    print <<'HELP';
compare-secplus.pl — Testmaker parser comparison tool

Compares extract-questions.pl and secplus-parser.pl output against
the SecurityTester reference questions.json.

USAGE
    perl tests/compare-secplus.pl [OPTIONS]

OPTIONS
    --secplus-txt PATH   Path to secplus.txt (default: C:/Code/SecurityTester/secplus.txt)
    --reference PATH     Path to SecurityTester questions.json
                         (default: C:/Code/SecurityTester/questions.json)
    -h, --help           Show this help

HELP
    exit 0;
}

my $script_dir  = dirname(abs_path($0));
my $project_dir = dirname($script_dir);

my $secplus_txt  = $opt_txt  // '/c/Code/SecurityTester/secplus.txt';
my $reference    = $opt_ref  // '/c/Code/SecurityTester/questions.json';
my $extract_pl   = "$project_dir/parsers/extract-questions.pl";
my $secplus_pl   = "$project_dir/parsers/secplus-parser.pl";

die "secplus.txt not found: $secplus_txt\n"  unless -e $secplus_txt;
die "reference not found: $reference\n"      unless -e $reference;
die "extract-questions.pl not found\n"       unless -e $extract_pl;
die "secplus-parser.pl not found\n"          unless -e $secplus_pl;

# ── Helper: load a Testmaker questions.json ───────────────────────────────────

sub load_testmaker_json {
    my ($path) = @_;
    require Encode;
    open(my $fh, '<:raw', $path) or die "Cannot open $path: $!\n";
    local $/;
    my $raw = <$fh>;
    close $fh;
    # Decode as UTF-8 with replacement chars for any stray bytes (e.g. soft hyphens
    # from cp1252 source files that weren't fully cleaned by the parser).
    my $text = Encode::decode('UTF-8', $raw, Encode::FB_DEFAULT());
    $text =~ s/\x{ad}//g;   # remove soft hyphens
    my $data = decode_json(Encode::encode('UTF-8', $text));
    return $data->{questions};
}

# ── Helper: load a flat array questions.json (SecurityTester format) ──────────

sub load_flat_json {
    my ($path) = @_;
    require Encode;
    open(my $fh, '<:raw', $path) or die "Cannot open $path: $!\n";
    local $/;
    my $raw = <$fh>;
    close $fh;
    my $text = Encode::decode('UTF-8', $raw, Encode::FB_DEFAULT());
    $text =~ s/\x{ad}//g;
    my $data = decode_json(Encode::encode('UTF-8', $text));
    # SecurityTester questions.json is a plain array
    return ref($data) eq 'ARRAY' ? $data : $data->{questions};
}

# ── Helper: question stats ────────────────────────────────────────────────────

sub stats {
    my ($questions, $label) = @_;
    my $total     = scalar @$questions;
    my $with_ans  = grep { defined $_->{correct} && $_->{correct} ne '' } @$questions;
    my $with_opts = grep { defined $_->{options} && scalar(keys %{$_->{options}}) >= 2 } @$questions;
    my $with_exp  = grep { defined $_->{explanation} && $_->{explanation} =~ /\S/ } @$questions;
    my $reviewed  = grep { $_->{_review} } @$questions;

    printf "  %-35s %6d\n", "Total questions:",        $total;
    printf "  %-35s %6d  (%d%%)\n", "With correct answer:",    $with_ans,  pct($with_ans, $total);
    printf "  %-35s %6d  (%d%%)\n", "With 2+ options:",        $with_opts, pct($with_opts, $total);
    printf "  %-35s %6d  (%d%%)\n", "With explanation:",       $with_exp,  pct($with_exp, $total);
    printf "  %-35s %6d\n", "Flagged for review:",       $reviewed  if $reviewed > 0;
}

sub pct {
    my ($n, $total) = @_;
    return 0 unless $total > 0;
    return int($n / $total * 100 + 0.5);
}

# ── Helper: run a parser and capture output ───────────────────────────────────

sub run_parser {
    my ($cmd, $outfile) = @_;
    my $stderr = `$cmd 2>&1 1>$outfile`;
    return $stderr;
}

# ── Run parsers ───────────────────────────────────────────────────────────────

my $tmp_general  = "/tmp/compare_general_$$.json";
my $tmp_specific = "/tmp/compare_specific_$$.json";

print "=" x 60 . "\n";
print "  TESTMAKER PARSER COMPARISON — Seidl Security+ SY0-701\n";
print "=" x 60 . "\n\n";

print "Input:     $secplus_txt\n";
print "Reference: $reference\n\n";

# ── 1. General parser ──────────────────────────────────────────────────────────

print "-" x 60 . "\n";
print "1. GENERAL PARSER (extract-questions.pl)\n";
print "-" x 60 . "\n";
print "Running...\n";

my $escaped = $secplus_txt;
$escaped =~ s/'/'\\''/g;
my $gen_stderr = run_parser(
    "perl \"$extract_pl\" \"$secplus_txt\" -n \"Security+ SY0-701\" 2>&1",
    $tmp_general
);

# Extract summary line
my ($gen_q, $gen_c, $gen_r) = (0, 0, 0);
if ($gen_stderr =~ /Questions:\s*(\d+)\s*\|\s*Categories:\s*(\d+)\s*\|\s*Review flags:\s*(\d+)/) {
    ($gen_q, $gen_c, $gen_r) = ($1 + 0, $2 + 0, $3 + 0);
}

if (-e $tmp_general && -s $tmp_general) {
    my $qs = load_testmaker_json($tmp_general);
    stats($qs, "General parser");
    print "\n";
    printf "  %-35s %s\n", "Categories detected:", $gen_c;
    printf "  %-35s %d/%d (%d%%)\n", "Cleanly parsed (no review flag):",
        $gen_q - $gen_r, $gen_q, pct($gen_q - $gen_r, $gen_q);

    # Show what the general parser DID get right (first 3 clean questions)
    my @clean = grep { !$_->{_review} } @$qs;
    if (@clean) {
        print "\n  Sample clean questions:\n";
        for my $q (@clean[0..($#clean > 2 ? 2 : $#clean)]) {
            printf "    [%s] %s\n", $q->{id}, substr($q->{question}, 0, 70);
        }
    }
} else {
    print "  ERROR: General parser produced no output.\n";
    print "  $gen_stderr\n";
}

# ── 2. Purpose-built parser ───────────────────────────────────────────────────

print "\n" . "-" x 60 . "\n";
print "2. PURPOSE-BUILT PARSER (secplus-parser.pl)\n";
print "-" x 60 . "\n";
print "Running...\n";

my $spec_stderr = run_parser(
    "perl \"$secplus_pl\" -f \"$secplus_txt\" 2>&1",
    $tmp_specific
);

if (-e $tmp_specific && -s $tmp_specific) {
    my $qs = load_testmaker_json($tmp_specific);
    stats($qs, "Purpose-built parser");
} else {
    print "  ERROR: Purpose-built parser produced no output.\n";
    print "  $spec_stderr\n";
}

# ── 3. SecurityTester reference ───────────────────────────────────────────────

print "\n" . "-" x 60 . "\n";
print "3. SECURITYTESTER REFERENCE (questions.json)\n";
print "-" x 60 . "\n";

my $ref_qs = load_flat_json($reference);
my $total_ref = scalar @$ref_qs;

printf "  %-35s %6d\n", "Total questions:", $total_ref;

my %by_chapter;
for my $q (@$ref_qs) {
    my $ch = $q->{chapter} // 'unknown';
    $by_chapter{$ch}++;
}
print "  Per chapter: ";
print join("  |  ", map { "Ch$_: $by_chapter{$_}" } sort { $a <=> $b } keys %by_chapter);
print "\n";

my $with_exp_ref = grep { defined $_->{explanation} && $_->{explanation} =~ /\S/ } @$ref_qs;
printf "  %-35s %6d  (%d%%)\n", "With explanation:", $with_exp_ref, pct($with_exp_ref, $total_ref);

# ── 4. Comparison summary ─────────────────────────────────────────────────────

print "\n" . "=" x 60 . "\n";
print "COMPARISON SUMMARY\n";
print "=" x 60 . "\n";

printf "  %-40s %6s   %6s   %6s\n",    "", "General", "Specific", "Ref";
printf "  %-40s %6s   %6s   %6s\n", "-" x 40, "-" x 6, "-" x 6, "-" x 6;

my ($spec_q, $spec_r) = (0, 0);
if (-e $tmp_specific && -s $tmp_specific) {
    my $qs = load_testmaker_json($tmp_specific);
    $spec_q = scalar @$qs;
    $spec_r = grep { $_->{_review} } @$qs;
}

printf "  %-40s %6d   %6d   %6d\n", "Total questions found:",      $gen_q,          $spec_q,          $total_ref;
printf "  %-40s %6d   %6d   %6s\n", "Review/warning flags:",       $gen_r,          $spec_r,          "n/a";
printf "  %-40s %6d%%  %6d%%  %6s\n","Clean parse rate:",
    pct($gen_q - $gen_r, $gen_q), pct($spec_q - $spec_r, $spec_q), "100%";

print "\n";
print "NOTES\n";
print "  General parser: designed for multi-line formatted text.\n";
print "  The Seidl PDF collapses each question + options onto one line\n";
print "  (a pdftotext layout artifact), so the general parser can locate\n";
print "  questions by number but cannot split out the inline A/B/C/D options.\n";
print "  For this document, secplus-parser.pl (purpose-built) is required.\n";
print "  The general parser performs well on multi-line formatted documents\n";
print "  (see tests/test-inline-answers.txt and tests/test-answer-key.txt).\n";

# ── Cleanup ───────────────────────────────────────────────────────────────────

unlink $tmp_general  if -e $tmp_general;
unlink $tmp_specific if -e $tmp_specific;

print "\nDone.\n";
