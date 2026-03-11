# Testmaker — Full Project Plan

## Goal
Build a generalized, self-contained browser-based practice test application that works with **any subject matter**. Users bring their own question data (JSON); the engine handles everything else — testing, scoring, progress tracking, review, and history.

Derived from the SecurityPlus practice test app (see `c:\Code\SecurityTester\`), generalized and made publicly distributable.

---

## Status

**Last updated: 2026-03-11**

| Milestone | Status |
|-----------|--------|
| Project planning | ✅ Done |
| Quiz engine (port from SecurityPlus) | ✅ Done |
| JSON import / question loading | ✅ Done |
| Question schema + validation | ✅ Done |
| JSON Schema file | ✅ Done |
| Sample question set | ✅ Done |
| AI-powered question extractor | ⬜ Pending |
| User README | ⬜ Pending |
| Dev README | ⬜ Pending |
| Testing & polish | ⬜ Pending |

---

## Deliverables

| File | Status | Purpose |
|------|--------|---------|
| `engine/quiz-engine.html` | ✅ | Self-contained quiz app — no questions embedded, loads from JSON |
| `parsers/extract-questions.pl` | ⬜ | AI-powered universal question extractor (any PDF/text → JSON) |
| `parsers/secplus-parser.pl` | ⬜ | Reference parser kept from SecurityTester project |
| `schemas/questions.schema.json` | ⬜ | Formal JSON schema for question data |
| `examples/sample-questions.json` | ✅ | 10 sample questions across 2 categories demonstrating all features |
| `README.md` | ⬜ | User-focused: how to use the app |
| `DEV.md` | ⬜ | Dev-focused: architecture, schema, how to build compatible data |
| `PLAN.md` | ✅ | This file |
| `CLAUDE.md` | ✅ | AI session handoff context |

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

## Phase 3 — AI-Powered Question Extractor

A command-line tool that takes any document and produces a valid questions.json.

- [ ] Input: PDF, plain text, or HTML file
- [ ] Uses Claude API (claude-sonnet-4-6 or claude-opus-4-6) to extract Q&A structure
- [ ] Outputs: valid JSON matching the schema
- [ ] Handles: multiple choice, true/false, explanations, categories/chapters
- [ ] Graceful fallback: flags questions it's unsure about for manual review
- [ ] Language: Perl (consistent with SecurityTester) or Python if needed

### Phase 3 — Lessons Learned
> _To be filled in when Phase 3 is complete._

---

## Phase 4 — Documentation

### README.md (User-focused)
- [ ] What Testmaker is
- [ ] How to open and use quiz-engine.html
- [ ] How to load a question set
- [ ] Where to get or create question sets
- [ ] FAQ

### DEV.md (Developer-focused)
- [ ] Project architecture
- [ ] Full questions.json schema with annotated example
- [ ] How to build a compatible question set manually
- [ ] How to run the AI extractor
- [ ] How to contribute / extend

### Phase 4 — Lessons Learned
> _To be filled in when Phase 4 is complete._

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
