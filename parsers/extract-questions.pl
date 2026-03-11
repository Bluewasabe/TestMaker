#!/usr/bin/perl
# extract-questions.pl — Free heuristic question parser for Testmaker
#
# Converts structured text, HTML, or PDF documents into a valid
# questions.json file for use with quiz-engine.html.
#
# No API key or internet connection required.
#
# USAGE
#   perl extract-questions.pl [OPTIONS] <file>
#
# OPTIONS
#   -o, --output FILE   Write JSON to FILE instead of stdout
#   -n, --name NAME     Override question set name (default: derived from filename)
#   -a, --author NAME   Set the author field in output metadata
#   -h, --help          Show this help message

use strict;
use warnings;
use JSON;
use Getopt::Long qw(:config no_ignore_case bundling);
use File::Basename;

# ── CLI ───────────────────────────────────────────────────────────────────────

my ($opt_output, $opt_name, $opt_author, $opt_help);
GetOptions(
    'output|o=s' => \$opt_output,
    'name|n=s'   => \$opt_name,
    'author|a=s' => \$opt_author,
    'help|h'     => \$opt_help,
) or die "Error in arguments. Run with --help for usage.\n";

if ($opt_help || !@ARGV) {
    show_help();
    exit 0;
}

my $infile = $ARGV[0];

# ── Main ──────────────────────────────────────────────────────────────────────

my @lines = load_file($infile);

my ($blocks_ref, $categories_ref, $answer_key_ref) = extract_structure(\@lines);

my ($questions_ref, $review_count) = parse_blocks($blocks_ref, $answer_key_ref);

# Build set name from filename if not provided
my $set_name = $opt_name;
unless ($set_name) {
    $set_name = basename($infile);
    $set_name =~ s/\.[^.]+$//;       # strip extension
    $set_name =~ s/[-_]/ /g;         # hyphens/underscores -> spaces
    $set_name =~ s/\b(\w)/uc($1)/ge; # title case
}

# Fall back to a default category if none were detected
if (!@$categories_ref) {
    $categories_ref = [{ id => 1, name => 'General' }];
}

# Assign uncategorized questions to the first category
for my $q (@$questions_ref) {
    $q->{category} = $categories_ref->[0]{id} + 0
        unless defined $q->{category};
}

my %output = (
    meta => {
        name       => $set_name,
        version    => '1.0',
        categories => $categories_ref,
        ($opt_author ? (author => $opt_author) : ()),
    },
    questions => $questions_ref,
);

my $json = JSON->new->utf8->pretty->encode(\%output);

if ($opt_output) {
    open(my $fh, '>:utf8', $opt_output) or die "Cannot write to $opt_output: $!\n";
    print $fh $json;
    close $fh;
    printf STDERR "Written: %s\n", $opt_output;
} else {
    binmode STDOUT, ':utf8';
    print $json;
}

printf STDERR "Questions: %d  |  Categories: %d  |  Review flags: %d\n",
    scalar @$questions_ref,
    scalar @$categories_ref,
    $review_count;

if ($review_count > 0) {
    print STDERR "\nReview the flagged questions above before loading in quiz-engine.html.\n";
    print STDERR "Remove or fix the _review/_note fields, then validate with questions.schema.json.\n";
}

exit 0;

# =============================================================================
# FILE LOADING
# =============================================================================

sub load_file {
    my ($path) = @_;
    die "File not found: $path\n" unless -e $path;

    my $ext = lc($path);
    $ext =~ s/.*\.//;

    my $text;

    if ($ext eq 'pdf') {
        # Requires pdftotext (poppler utils)
        my $escaped = $path;
        $escaped =~ s/'/'\\''/g;
        $text = `pdftotext '$escaped' -`;
        if ($? != 0 || !defined $text || $text eq '') {
            die "pdftotext failed. Install poppler and ensure pdftotext is in your PATH.\n"
              . "On Windows: choco install poppler  or  winget install GnuWin32.GnuWin32\n";
        }
    } elsif ($ext eq 'html' || $ext eq 'htm') {
        open(my $fh, '<:utf8', $path) or die "Cannot open $path: $!\n";
        local $/;
        $text = <$fh>;
        close $fh;
        $text = strip_html($text);
    } elsif ($ext eq 'txt') {
        open(my $fh, '<:utf8', $path) or die "Cannot open $path: $!\n";
        local $/;
        $text = <$fh>;
        close $fh;
    } else {
        die "Unsupported file type: .$ext\n"
          . "Supported formats: .txt  .html  .htm  .pdf\n";
    }

    return normalize_lines($text);
}

sub strip_html {
    my ($html) = @_;
    # Decode named entities
    $html =~ s/&amp;/&/g;
    $html =~ s/&lt;/</g;
    $html =~ s/&gt;/>/g;
    $html =~ s/&quot;/"/g;
    $html =~ s/&apos;/'/g;
    $html =~ s/&nbsp;/ /g;
    $html =~ s/&mdash;/—/g;
    $html =~ s/&ndash;/-/g;
    $html =~ s/&ldquo;/"/g;
    $html =~ s/&rdquo;/"/g;
    $html =~ s/&lsquo;/'/g;
    $html =~ s/&rsquo;/'/g;
    # Decode numeric entities
    $html =~ s/&#(\d+);/chr($1)/ge;
    $html =~ s/&#x([0-9a-fA-F]+);/chr(hex($1))/ge;
    # Insert newlines around block-level elements
    $html =~ s{</?(?:p|div|br|li|h[1-6]|tr|td|th|blockquote|pre|ul|ol)[^>]*>}{\n}gi;
    # Remove remaining tags
    $html =~ s/<[^>]+>//g;
    return $html;
}

sub normalize_lines {
    my ($text) = @_;
    $text =~ s/\r\n/\n/g;
    $text =~ s/\r/\n/g;
    $text =~ s/\x0C/\n/g;                        # form feed (PDF page breaks)
    $text =~ s/\x{ad}//g;                        # soft hyphen
    $text =~ s/([a-z])-\s{1,2}([a-z])/$1$2/g;   # PDF hyphenation artifact

    my @lines;
    for my $line (split /\n/, $text) {
        $line =~ s/\s+$//;   # rtrim
        push @lines, $line;
    }
    return @lines;
}

# =============================================================================
# STRUCTURE EXTRACTION
# Scans lines to:
#   - detect category headings
#   - split question blocks
#   - locate and parse a separate answer key section
# Returns: (\@blocks, \@categories, \%answer_key)
# =============================================================================

sub extract_structure {
    my ($lines_ref) = @_;

    # Find answer key section (scan from end of file)
    my $answer_section_start = -1;
    for my $i (reverse 0..$#$lines_ref) {
        if ($lines_ref->[$i] =~ /^\s*(answer\s+key|answers\s*$|correct\s+answers?)\s*$/i) {
            $answer_section_start = $i;
            last;
        }
    }

    my $scan_end = ($answer_section_start > 0)
        ? $answer_section_start - 1
        : $#$lines_ref;

    # Scan lines for categories and question blocks
    my @blocks;
    my @categories;
    my %seen_cats;
    my $next_cat_id = 1;
    my $current_cat_id = undef;  # undef = not yet assigned

    my $current_block = undef;

    for my $i (0..$scan_end) {
        my $line = $lines_ref->[$i];

        # Detect category heading
        my $cat_name = heading_name($line);
        if (defined $cat_name && !$seen_cats{lc($cat_name)}++) {
            push @categories, { id => $next_cat_id, name => $cat_name };
            $current_cat_id = $next_cat_id;
            $next_cat_id++;

            # Finalize current block before new category
            if ($current_block && @{$current_block->{lines}}) {
                push @blocks, $current_block;
            }
            $current_block = undef;
            next;
        }

        # Detect question start
        if (is_question_start($line)) {
            if ($current_block && @{$current_block->{lines}}) {
                push @blocks, $current_block;
            }
            $current_block = {
                lines  => [],
                cat_id => $current_cat_id,  # may be undef if no heading yet
            };
        }

        push @{$current_block->{lines}}, $line if $current_block;
    }

    # Finalize last block
    if ($current_block && @{$current_block->{lines}}) {
        push @blocks, $current_block;
    }

    # Parse answer key section if found
    my %answer_key;
    if ($answer_section_start > 0) {
        my @ak_lines = @{$lines_ref}[$answer_section_start..$#$lines_ref];
        %answer_key = parse_answer_key(\@ak_lines);
        printf STDERR "Answer key section found at line %d: %d answers extracted\n",
            $answer_section_start + 1, scalar keys %answer_key;
    }

    return (\@blocks, \@categories, \%answer_key);
}

# Return the category name if $line looks like a section heading, undef otherwise
sub heading_name {
    my ($line) = @_;
    return undef if $line =~ /^\s*$/;

    # "Chapter N", "Section N", "Unit N", "Module N", "Part N", "Topic N"
    # optionally followed by ": Name" or "- Name" or just the name
    if ($line =~ /^\s*(Chapter|Section|Unit|Module|Part|Topic)\s+(\d+)[:\s\-–—]*(.*)/i) {
        my ($type, $num, $rest) = (ucfirst(lc($1)), $2, $3 // '');
        $rest =~ s/^\s+|\s+$//g;
        return $rest ? "$type $num: $rest" : "$type $num";
    }

    # Markdown headings: # / ## / ###
    if ($line =~ /^#{1,3}\s+(.+)/) {
        my $name = $1;
        $name =~ s/^\s+|\s+$//g;
        return $name if length($name) >= 3;
    }

    # ALL-CAPS lines (heading heuristic):
    # - 10-80 chars, at least 2 words, no question mark, no option pattern
    if ($line =~ /^[A-Z][A-Z0-9 \t:,\-–]{9,79}$/) {
        return undef if $line =~ /[?]/;
        return undef if $line =~ /^\s*\d+[.)]/;           # looks like a question
        return undef if $line =~ /^\s*[A-D][.)]\s/;       # looks like an option
        my @words = split /\s+/, $line;
        return $line if @words >= 2;
    }

    return undef;
}

# Return true if $line starts a new question
sub is_question_start {
    my ($line) = @_;
    return 1 if $line =~ /^\s*\d+[.)]\s+\S/;          # "1. text" or "1) text"
    return 1 if $line =~ /^\s*Q\d+[.):]\s+\S/i;        # "Q1. text" or "Q1: text"
    return 1 if $line =~ /^\s*Question\s+\d+[.):]\s+\S/i;  # "Question 1: text"
    return 1 if $line =~ /^\s*\(\d+\)\s+\S/;           # "(1) text"
    return 0;
}

# =============================================================================
# ANSWER KEY PARSING
# Parses a standalone "Answer Key" or "Answers" section.
# Returns: %answer_key = ( question_number => { letter => 'B', explanation => '...' } )
# =============================================================================

sub parse_answer_key {
    my ($lines_ref) = @_;
    my %answers;
    my $current_num    = 0;
    my $current_letter = '';
    my @exp_lines;

    my $save_current = sub {
        return unless $current_num > 0;
        my $exp = join(' ', @exp_lines);
        $exp =~ s/\s+/ /g;
        $exp =~ s/^\s+|\s+$//g;
        $answers{$current_num} = { letter => $current_letter, explanation => $exp };
    };

    for my $line (@$lines_ref) {
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*(answer\s+key|answers?\s*$|correct\s+answers?)/i;

        # "1. B"  "1) C"  "1. B."  "1. B - explanation"  "1. B. explanation"
        if ($line =~ /^\s*(\d+)[.)]\s+([A-Da-d])[.):\s-]*(.*)/) {
            my ($num, $letter, $rest) = ($1 + 0, uc($2), $3 // '');
            $rest =~ s/^[\s\-–—.:]+//;
            $save_current->();
            $current_num    = $num;
            $current_letter = $letter;
            @exp_lines      = ($rest =~ /\S/) ? ($rest) : ();
            next;
        }

        # True/False answer: "1. True" or "1) False"
        if ($line =~ /^\s*(\d+)[.)]\s+(True|False)\b(.*)/i) {
            my ($num, $tf, $rest) = ($1 + 0, ucfirst(lc($2)), $3 // '');
            $rest =~ s/^[\s\-–—.:]+//;
            $save_current->();
            $current_num    = $num;
            $current_letter = $tf;
            @exp_lines      = ($rest =~ /\S/) ? ($rest) : ();
            next;
        }

        # Continuation line (explanation text)
        push @exp_lines, $line if $current_num > 0;
    }

    $save_current->();
    return %answers;
}

# =============================================================================
# BLOCK PARSING
# Parses each question block using a line-by-line state machine.
# =============================================================================

sub parse_blocks {
    my ($blocks_ref, $answer_key_ref) = @_;

    my @questions;
    my $review_count = 0;
    my %cat_qcount;   # tracks question index per category for ID generation

    for my $block (@$blocks_ref) {
        my $cat_id = $block->{cat_id} // 1;
        $cat_id = $cat_id + 0;  # ensure integer
        $cat_qcount{$cat_id} //= 0;
        $cat_qcount{$cat_id}++;

        my $q = parse_question_block(
            $block->{lines},
            $cat_id,
            $cat_qcount{$cat_id},
            $answer_key_ref
        );

        next unless $q;

        if ($q->{_review}) {
            $review_count++;
            my $note = $q->{_note} // 'low confidence';
            printf STDERR "[REVIEW] %s: %s\n", $q->{id}, $note;
        }

        push @questions, $q;
    }

    return (\@questions, $review_count);
}

# Parse a single question block (arrayref of lines).
# Returns a question hashref, or undef if unparseable.
sub parse_question_block {
    my ($lines_ref, $cat_id, $qnum, $answer_key_ref) = @_;

    my $id = sprintf('cat%d_q%d', $cat_id, $qnum);

    # States
    my $STATE_Q    = 'Q';   # reading question text
    my $STATE_OPTS = 'O';   # reading options
    my $STATE_POST = 'P';   # after options (answer/explanation lines)

    my $state = $STATE_Q;
    my $q_num_raw = undef;

    my @question_lines;
    my %options;
    my @option_order;   # track insertion order
    my $last_key = undef;

    my $correct = undef;
    my @explanation_lines;
    my $in_explanation = 0;

    for my $raw_line (@$lines_ref) {
        my $line = $raw_line;
        next if $line =~ /^\s*$/;

        # ── Strip question number from the very first content line ──────────
        if ($state eq $STATE_Q && !@question_lines) {
            if    ($line =~ s/^\s*(\d+)[.)]\s+//)          { $q_num_raw = $1 + 0 }
            elsif ($line =~ s/^\s*Q(\d+)[.):]\s+//i)       { $q_num_raw = $1 + 0 }
            elsif ($line =~ s/^\s*Question\s+(\d+)[.):]\s+//i) { $q_num_raw = $1 + 0 }
            elsif ($line =~ s/^\s*\((\d+)\)\s+//)          { $q_num_raw = $1 + 0 }
            next unless $line =~ /\S/;
        }

        # ── Explanation marker ───────────────────────────────────────────────
        if ($line =~ /^\s*(Explanation|Rationale|Why|Reason|Note):\s*(.*)/i) {
            my $exp_rest = $2;
            $in_explanation = 1;
            $state = $STATE_POST;
            push @explanation_lines, $exp_rest if defined $exp_rest && $exp_rest =~ /\S/;
            next;
        }
        if ($in_explanation) {
            push @explanation_lines, $line;
            next;
        }

        # ── Inline answer marker ─────────────────────────────────────────────
        # "Answer: B", "Correct Answer: B", "Correct: B"
        if ($line =~ /^\s*(?:Correct\s+)?Answers?(?:\s+Key)?:\s*([A-Da-dTF][a-z]*)\b(.*)/i) {
            $correct //= ucfirst(lc($1)) if $1 =~ /true|false/i;
            $correct //= uc($1);
            my $rest = $2 // '';
            $rest =~ s/^[\s\-–—.:]+//;
            push @explanation_lines, $rest if $rest =~ /\S/;
            $state = $STATE_POST;
            next;
        }

        # ── Option line ──────────────────────────────────────────────────────
        # Handles: "A. text", "A) text", "(A) text" — both cases
        if ($line =~ /^\s*([A-Da-d])[.)]\s+(.+)/ ||
            $line =~ /^\s*\(([A-Da-d])\)\s+(.+)/) {
            my ($key, $val) = (uc($1), $2);
            $val =~ s/\s+$//;
            unless (exists $options{$key}) {
                push @option_order, $key;
            }
            $options{$key} = $val;
            $last_key = $key;
            $state = $STATE_OPTS;
            next;
        }

        # ── True / False option lines (bare) ─────────────────────────────────
        if ($line =~ /^\s*(True|False)\s*$/ && $state eq $STATE_OPTS) {
            my $key = ucfirst(lc($1));
            unless (exists $options{$key}) {
                push @option_order, $key;
                $options{$key} = $key;
            }
            $last_key = $key;
            next;
        }

        # ── Continuation of last option ──────────────────────────────────────
        if ($state eq $STATE_OPTS && defined $last_key) {
            # Don't swallow lines that start a new structure
            last if $line =~ /^\s*(Explanation|Rationale|Answer|Correct):/i;
            $options{$last_key} .= ' ' . $line;
            $options{$last_key} =~ s/\s+/ /g;
            next;
        }

        # ── Regular question text ────────────────────────────────────────────
        push @question_lines, $line if $state eq $STATE_Q;
    }

    # ── Assemble question text ───────────────────────────────────────────────
    my $question_text = join(' ', @question_lines);
    $question_text =~ s/\s+/ /g;
    $question_text =~ s/^\s+|\s+$//g;

    return undef unless $question_text =~ /\S/;

    # ── True/False detection ─────────────────────────────────────────────────
    # If no options were found but question asks "True or False"
    if (!%options && $question_text =~ /\b(true\s+or\s+false|true\/false)\b/i) {
        %options    = ('True' => 'True', 'False' => 'False');
        @option_order = ('True', 'False');
    }

    # ── Answer from separate answer key ──────────────────────────────────────
    if (!$correct && defined $q_num_raw && exists $answer_key_ref->{$q_num_raw}) {
        my $ak = $answer_key_ref->{$q_num_raw};
        if (ref $ak eq 'HASH') {
            $correct = $ak->{letter};
            if (!@explanation_lines && $ak->{explanation} =~ /\S/) {
                push @explanation_lines, $ak->{explanation};
            }
        } else {
            $correct = $ak;
        }
    }

    # ── Asterisk-marked correct option (*) ───────────────────────────────────
    unless ($correct) {
        for my $key (@option_order) {
            if ($options{$key} =~ s/\s*\*\s*$//) {
                $correct = $key;
                last;
            }
        }
    }

    # ── Normalize correct answer ─────────────────────────────────────────────
    if (defined $correct) {
        $correct = uc($correct) unless $correct =~ /^(True|False)$/i;
        $correct = ucfirst(lc($correct)) if $correct =~ /^(TRUE|FALSE)$/i;
    }

    my $explanation_text = join(' ', @explanation_lines);
    $explanation_text =~ s/\s+/ /g;
    $explanation_text =~ s/^\s+|\s+$//g;

    # ── Build ordered options hash (A before B before C before D) ────────────
    # Use a tied hash or just build an arrayref. JSON::PP respects insertion
    # order if we use a plain hashref built in order.
    my %ordered_opts;
    for my $key (@option_order) {
        $ordered_opts{$key} = $options{$key};
    }

    my %result = (
        id       => $id,
        category => $cat_id + 0,
        question => $question_text,
        options  => \%ordered_opts,
        correct  => $correct // '',
    );

    $result{explanation} = $explanation_text if $explanation_text =~ /\S/;

    # ── Confidence check ─────────────────────────────────────────────────────
    my @issues;
    push @issues, 'fewer than 2 options detected'
        if scalar(keys %options) < 2;
    push @issues, 'answer missing or not found in options'
        if !$correct || !exists $options{$correct};
    push @issues, 'question text very short'
        if length($question_text) < 10;

    if (@issues) {
        $result{_review} = JSON::true;
        $result{_note}   = join('; ', @issues);
    }

    return \%result;
}

# =============================================================================
# HELP
# =============================================================================

sub show_help {
    print <<'HELP';
extract-questions.pl — Free heuristic question parser for Testmaker

USAGE
    perl extract-questions.pl [OPTIONS] <file>

ARGUMENTS
    <file>    Input file (.txt, .html, .htm, or .pdf)
              PDF requires pdftotext (poppler) to be installed.

OPTIONS
    -o, --output FILE   Write JSON to FILE instead of stdout
    -n, --name NAME     Override question set name (default: derived from filename)
    -a, --author NAME   Set the author field in output metadata
    -h, --help          Show this help message

OUTPUT
    Writes a questions.json file compatible with quiz-engine.html.

    Questions that could not be parsed cleanly are flagged with
    "_review": true and a "_note" field describing the issue.
    These must be corrected before loading in the quiz engine
    (the schema does not allow extra fields).

EXAMPLES
    perl extract-questions.pl study-guide.txt -o questions.json
    perl extract-questions.pl chapter1.pdf -n "Chapter 1 Quiz" -a "Jane"
    perl extract-questions.pl notes.html -o out.json

SUPPORTED INPUT PATTERNS
    Questions:     1.  1)  Q1.  Q1:  Question 1:  (1)
    Options:       A.  A)  (A)  a.   a)
    True/False:    "True or False:" in question text, or bare True/False lines
    Inline answer: Answer: B  |  Correct Answer: C
    Explanations:  Explanation:  Rationale:  Why:  Note:  Reason:
    Answer keys:   Separate "Answer Key" section at end of document
                   Lines like "1. B" or "1. B. Explanation text"
    Categories:    Chapter N  Section N  ## Heading  ALL CAPS LINES

NOTES
    - Accuracy depends heavily on document consistency. Clean, consistently
      formatted documents parse much better than mixed/messy ones.
    - For difficult documents, consider the AI parser (parsers/ai-extract.pl).
    - Inspect stderr output for REVIEW warnings before using the output.

HELP
}
