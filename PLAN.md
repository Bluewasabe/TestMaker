# Testmaker — Full Project Plan

## Goal
Build a generalized, self-contained browser-based practice test application that works with **any subject matter**. Users bring their own question data (JSON); the engine handles everything else — testing, scoring, progress tracking, review, and history.

Derived from the SecurityPlus practice test app (see `c:\Code\SecurityTester\`), generalized and made publicly distributable.

---

## Status

**Last updated: 2026-03-11** *(Phase 5 complete)*

| Phase | Milestone | Status |
|-------|-----------|--------|
| — | Project planning | ✅ Done |
| 1 | Quiz engine (port from SecurityPlus) | ✅ Done |
| 2 | Question schema + validation + sample set | ✅ Done |
| 3 | Free question parser (regex/heuristic) | ✅ Done |
| 4 | Documentation (README + DEV.md) | ✅ Done |
| 5 | Testing & polish | ✅ Done |
| 6 | AI model integration (enhancement) | ⬜ Pending |

---

## Deliverables

| File | Status | Purpose |
|------|--------|---------|
| File | Status | Phase | Purpose |
|------|--------|-------|---------|
| `engine/quiz-engine.html` | ✅ | 1 | Self-contained quiz app — no questions embedded, loads from JSON |
| `schemas/questions.schema.json` | ✅ | 2 | Formal JSON schema for question data |
| `examples/sample-questions.json` | ✅ | 2 | 10 sample questions across 2 categories demonstrating all features |
| `parsers/extract-questions.pl` | ✅ | 3 | Free regex/heuristic parser (any structured text/PDF → JSON) |
| `parsers/secplus-parser.pl` | ✅ | 3 | Reference parser kept from SecurityTester project |
| `README.md` | ✅ | 4 | User-focused: how to use the app |
| `DEV.md` | ✅ | 4 | Dev-focused: architecture, schema, how to build compatible data |
| `parsers/ai-extract.pl` | ⬜ | 6 | AI-powered extractor — multi-provider, cost transparency, chunking |
| `tests/test-inline-answers.txt` | ✅ | 5 | Parser test: inline `Answer: X` format |
| `tests/test-answer-key.txt` | ✅ | 5 | Parser test: separate answer key section format |
| `tests/test-truefalse.txt` | ✅ | 5 | Parser test: bare True/False option lines + mixed format |
| `tests/compare-secplus.pl` | ✅ | 5 | Comparison tool: general vs purpose-built parser vs SecurityTester reference |
| `PLAN.md` | ✅ | — | This file |
| `CLAUDE.md` | ✅ | — | AI session handoff context |

---

## Phase 1 — Quiz Engine

Port the SecurityPlus HTML app to be data-agnostic.

### Changes from SecurityPlus version
- [x] Remove hardcoded question data (no embedded JSON)
- [x] Add **question set loader**: drag-and-drop or file picker for `.json` files
- [x] Add **question set metadata**: name, description, author, version (from JSON header)
- [x] Replace domain-specific labels with generic "category" terminology
- [x] Support variable number of categories (not hardcoded to 5 domains)
- [x] Support 2, 3, or 4 answer options (not hardcoded to A/B/C/D)
- [x] Support optional explanations (field not required)
- [x] Keep all existing features: immediate/summary mode, shuffle, timer, history, keyboard shortcuts, weak-question filter, exam simulation

### Question Set Loading
- [x] On first load: show welcome screen with file picker + drag-and-drop zone
- [x] Remember last loaded question set in localStorage
- [x] Allow switching question sets (clears current session, prompts user)
- [x] Show question set info (name, count, categories) before starting

### Retained Features (from SecurityPlus)
- [x] Home dashboard: overall accuracy, per-category bars, recent sessions
- [x] Config screen: category filter, question count, mode, shuffle toggles, weak-only filter, timer
- [x] Test screen: progress bar, immediate feedback with explanations, flag button
- [x] Review screen: score, pass/fail, category breakdown, expandable question list
- [x] Exam simulation mode: configurable question count + time limit
- [x] History view: session log, clear button
- [x] Keyboard shortcuts: 1-4/A-D select, Enter next, F flag, ←→ navigate
- [x] Full localStorage persistence

### Phase 1 — Lessons Learned
- Porting from SecurityPlus was faster than expected — the JS was already clean and the generalization was mostly search/replace of `q.chapter` → `q.category` and removing hardcoded domain arrays.
- `esc()` must stay a `function` declaration (not a `const` arrow) — it is called from dynamically built `onclick` strings before the script block finishes, so hoisting is required.
- Option shuffling should swap values behind the same keys, not rename keys — simpler `correct` remapping and keeps option labels stable.
- The "Continue →" cache banner pattern is better than silent auto-load — gives users control without re-upload friction for the common case.
- Category IDs must be integers. Strict equality (`===`) is used throughout; string IDs silently break all category filtering with no error.
- localStorage caching of large sets can hit quota limits — wrap in `try/catch` and accept in-memory-only as the graceful fallback.

---

## Phase 2 — Question Schema & Validation

### JSON Schema (questions.schema.json)
Define and document the canonical format for question data files.

- [x] Write formal JSON Schema (draft-07 or 2020-12)
- [x] Required fields: `meta`, `questions` array
- [x] Meta fields: `name`, `description`, `version`, `author`, `categories`
- [x] Question fields: `id`, `category`, `question`, `options`, `correct`, `explanation` (optional)
- [x] Validation: client-side schema check when loading a file, friendly error messages

### Example File
- [x] Write `examples/sample-questions.json` — 10 questions across 2 categories demonstrating all features
- [x] Include questions with 2 or 3 options (currently all 4-option)
- [x] Include questions with and without explanations

### Phase 2 — Lessons Learned
- JSON Schema draft-07 cannot enforce that `correct` matches a key in `options` (cross-field reference). This constraint is documented in the schema description and enforced by the engine's client-side validator at load time.
- True/False questions work cleanly with string option keys (`"True"`/`"False"`) — option keys don't have to be A/B/C/D. The `correct` field is just the matching key string.
- `additionalProperties: false` on both `meta` and question objects makes the schema strict: any extra fields will fail validation. This is intentional — keeps question files clean and predictable.

---

## Phase 3 — Free Question Parser

A zero-cost command-line Perl parser that converts structured text/PDF documents into valid `questions.json` files using regex and heuristics — no API key or internet connection required.

### Input handling
- [x] Accept `.txt`, `.html`/`.htm`, and `.pdf` (PDF via `pdftotext` system command)
- [x] HTML: strip tags, decode common entities
- [x] Graceful error if file not found or format unsupported

### Pattern detection
- [x] Detect numbered questions (`1.`, `Q1.`, `Question 1:`, etc.)
- [x] Detect lettered options (`A.`, `A)`, `(A)`, `a.` etc.)
- [x] Detect True/False questions
- [x] Detect answer keys (inline `Answer: B` or separate answer key section)
- [x] Detect explanations (`Explanation:`, `Rationale:`, `Why:` etc.)
- [x] Infer categories from headings (`Chapter 3`, `Section:`, `##`, all-caps lines)

### Output
- [x] Output valid JSON matching `questions.schema.json`
- [x] Auto-generate `id` values (`cat1_q1`, `cat2_q3`, etc.)
- [x] Flag low-confidence questions with a stderr warning and `_review` comment in output
- [x] `--output / -o FILE` — write to file instead of stdout
- [x] `--name / -n NAME` — override question set name (default: derived from filename)
- [x] `--author / -a NAME` — optional author field
- [x] `--help / -h` — usage info

### Phase 3 — Lessons Learned
- **Save `$1`/`$2` to locals immediately.** In Perl, any subsequent regex (`$1 =~ /pattern/`) resets `$1` and `$2` even in the same expression. Using them in an `if $1 =~ /...` condition and then referencing `$1` in the conditional body gives undef. Always: `my ($x, $y) = ($1, $2)` right after the match.
- **State machine is more robust than a joined-string regex for options.** A line-by-line state machine handles multi-line question text and multi-line options naturally. Trying to parse a whole joined block with one regex fails on edge cases and produces confusing captures.
- **Separate answer key section detection works well when scanned from the end.** The last occurrence of a line matching `answer key|answers` is almost certainly the section header. Scanning from the end avoids false positives on "Answer: B" inline markers in the question body.
- **The `|` delimiter in Perl `s///` conflicts with alternation.** `s|</?(p|div)|...|` is ambiguous — the parser reads `|` as the delimiter and breaks the alternation. Use `s{...}{...}` for substitutions whose patterns contain `|`.
- **True/False answers need normalized casing.** Option keys in the schema are `"True"` / `"False"` (title case). The parser must produce `ucfirst(lc($ans))` when it detects a True/False answer, not `uc()`, or the answer won't match the option key.

---

## Phase 4 — Documentation

### README.md (User-focused)
- [x] What Testmaker is
- [x] How to open and use `quiz-engine.html`
- [x] How to load a question set
- [x] Where to get or create question sets (manual JSON, free parser, AI parser)
- [x] FAQ

### DEV.md (Developer-focused)
- [x] Project architecture
- [x] Full `questions.json` schema with annotated example
- [x] How to build a compatible question set manually
- [x] How to run the free parser (`extract-questions.pl`)
- [x] Known limitations of the free parser
- [x] How to contribute / extend

### Phase 4 — Lessons Learned
- README structure (User Focus → Developer Focus → Enhancement Ideas from CLAUDE.md standard) maps well onto a tool like Testmaker where the user and developer are often different people.
- DEV.md benefits from an annotated inline-comment JSON example more than a table alone — the side-by-side format makes required vs optional fields immediately obvious.
- Documenting known limitations explicitly (rename orphans history, localStorage quota) prevents future confusion and makes the project feel honest and well-understood.

---

## Phase 5 — Testing & Polish

- [x] Test quiz engine with `sample-questions.json` end-to-end
- [x] Test free parser against at least 3 different input formats
- [x] Verify schema validation errors display correctly in the engine
- [ ] Cross-browser check (Chrome, Firefox, Edge) for `quiz-engine.html` *(manual; deferred to pre-release)*
- [x] Review all user-facing text for clarity
- [x] Final copyright scan before push
- [x] Run free parser + purpose-built parser against David Seidl PDF; compare to SecurityTester reference (1,005 questions) — results in Lessons Learned

### Phase 5 — Lessons Learned

**Parser bug fixed: bare True/False option lines not detected in STATE_Q**
The `extract-questions.pl` state machine only matched bare `True`/`False` option lines when already in `STATE_OPTS` (i.e., after at least one `A.` option was found). For True/False questions where "True" and "False" appear on their own lines directly below the question text, the state machine was still in `STATE_Q` and absorbed them as question text. Fix: fire the True/False option check when `$state eq STATE_Q` and `@question_lines` is non-empty.

**Parser: .txt files must handle Windows-1252 encoding**
Real-world PDF-extracted text files (e.g., pdftotext output from Sybex books) are often saved in Windows-1252 (cp1252), not UTF-8. Opening with `<:utf8` causes a fatal error on bytes like `\xAE` (®) and `\xA9` (©). Fix: open as `:raw`, decode as UTF-8 with `Encode::FB_CROAK`, fall back to `cp1252` on failure, and warn on stderr. This keeps UTF-8 clean files working without change.

**Seidl PDF format: general parser cannot handle single-line question layout**
The pdftotext output from the Seidl Security+ book collapses each question and its four options onto a single line. The general heuristic parser (line-by-line state machine) can locate question numbers but cannot split `"Question text? A. opt B. opt C. opt D. opt"` into distinct fields. Result: 1,006 question titles found, 0 cleanly parsed, 1,006 review flags. The purpose-built `secplus-parser.pl` handles this via a single-line regex and gets 1,005/1,005 complete questions — matching SecurityTester exactly. **This is expected and correct.** The general parser is designed for multi-line formatted text; single-line format requires a purpose-built parser.

**Comparison tool: `tests/compare-secplus.pl`**
A Perl script was added to automate the parser comparison: runs both parsers against `secplus.txt`, loads the SecurityTester reference, and prints a side-by-side stats table. Useful for future regression testing after parser changes. The Seidl content is not committed — the script runs locally and reports stats only.

**schema validation in engine checks only first 5 questions**
The `validateData()` function in `quiz-engine.html` checks `min(5, questions.length)` items. This is intentional for performance, but means a file with valid first 5 questions and broken later ones will load without an error. Documented as a known limitation. Users should use the JSON schema (`schemas/questions.schema.json`) for full validation.

**sample-questions.json: 12 questions, all valid**
Validated programmatically: all 12 questions have valid categories, correct answers that exist in options, and explanations. 4-option, 3-option, and 2-option (True/False) formats all present and passing.

---

## Phase 6 — AI Model Integration (Enhancement)

An optional AI-powered upgrade to the parser. When enabled, sends document text to an LLM and gets back structured JSON — handles messy, inconsistently formatted documents that the regex parser cannot reliably parse.

### Provider support
- [ ] Pluggable provider system — user selects via `--provider` flag
- [ ] **Anthropic** (default): `claude-sonnet-4-6`, `claude-haiku-4-5`
- [ ] **OpenAI**: `gpt-4o`, `gpt-4o-mini`
- [ ] **Ollama** (local/free): any locally running model via `http://localhost:11434`
- [ ] API key from environment variable (never hardcoded): `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`

### Cost transparency (shown before every API call)
- [ ] Estimate input token count and display before sending
- [ ] Show per-provider cost estimate based on current known pricing
- [ ] Display one-time cost reminder: _"You run the extractor once; the quiz engine is free forever after"_
- [ ] `--dry-run` flag — show token estimate and cost estimate without calling the API

### Cost-saving options
- [ ] `--model MODEL` — override default model (e.g. use Haiku instead of Sonnet to cut cost ~20x)
- [ ] Input truncation with warning when document exceeds safe token limit
- [ ] `--chunk` flag — split large documents by detected chapter/section and process one chunk at a time (lets you retry failed sections without re-sending the whole doc)
- [ ] Show running cost total when `--chunk` is used across multiple calls

### Output
- [ ] Same JSON schema as free parser — output is interchangeable
- [ ] Flag uncertain questions for manual review (stderr warning + question list)
- [ ] `--merge FILE` — merge AI output into an existing questions.json (append questions, deduplicate by id)

### Phase 6 — Lessons Learned
> _To be filled in when Phase 6 is complete._

---

## questions.json Schema

### File Structure
```json
{
  "meta": {
    "name": "My Study Set",
    "description": "Optional description",
    "version": "1.0",
    "author": "Optional",
    "examInfo": {
      "questionCount": 90,
      "timeMinutes": 90,
      "passingPercent": 83
    },
    "categories": [
      { "id": 1, "name": "Category Name", "weight": 20 }
    ]
  },
  "questions": [
    {
      "id": "cat1_q1",
      "category": 1,
      "question": "Question text here?",
      "options": {
        "A": "First option",
        "B": "Second option",
        "C": "Third option",
        "D": "Fourth option"
      },
      "correct": "B",
      "explanation": "Optional explanation text."
    }
  ]
}
```

### Field Reference
| Field | Required | Notes |
|-------|----------|-------|
| `meta.name` | ✅ | Displayed in app header |
| `meta.categories` | ✅ | Array; id + name required, weight optional |
| `questions[].id` | ✅ | Must be unique within the file |
| `questions[].category` | ✅ | Must match a `meta.categories[].id` |
| `questions[].question` | ✅ | Question text |
| `questions[].options` | ✅ | Object; keys are option labels (A/B/C/D or 1/2/3 etc.) |
| `questions[].correct` | ✅ | Must match a key in `options` |
| `questions[].explanation` | ⬜ | Optional; shown after answering |
| `meta.description` | ⬜ | Optional |
| `meta.author` | ⬜ | Optional |
| `meta.examInfo` | ⬜ | Optional; enables exam simulation mode |

---

## UI Design

### Theme
Inherited from SecurityPlus app:
- Dark mode
- Background: `#0f1117`
- Card: `#1a1d2e`
- Primary: `#6366f1` (indigo)
- Correct: `#22c55e`
- Wrong: `#ef4444`
- Warning: `#f59e0b`
- Text: `#e2e8f0`

### Views
1. **Load** — welcome screen when no question set is loaded
2. **Home** — dashboard (stats, recent sessions)
3. **Config** — test setup
4. **Test** — active test
5. **Review** — end-of-test results
6. **History** — all past sessions

---

## localStorage Schema

### Key: `tm_data` (per question set, namespaced by question set name)
```json
{
  "setName": "My Study Set",
  "sessions": [...],
  "questions": { "cat1_q1": { "attempts": 3, "correct": 2 } }
}
```

### Key: `tm_config`
```json
{
  "lastFile": "my-questions.json",
  "categories": [1, 2, 3],
  "count": 20,
  "mode": "immediate",
  "shuffle": true,
  "shuffleOptions": true,
  "weakOnly": false,
  "timer": false
}
```

---

## Key Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Question data source | External JSON file loaded by user | Avoids copyright issues; keeps engine publishable |
| File loading method | Browser File API (drag-drop + picker) | No server needed, works with file:// |
| Build tooling | None (vanilla HTML/JS) | Zero dependencies, maximum portability |
| AI extractor language | Perl (primary) | Consistent with SecurityTester; Claude API via HTTP |
| Publish to GitHub | Yes (engine + schema only, no copyrighted content) | Clean, safe, useful to others |
