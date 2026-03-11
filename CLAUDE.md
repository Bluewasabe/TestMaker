# CLAUDE.md — Testmaker

This file provides context for AI sessions working on this project.

## Copyright Policy

This project is designed to be published publicly on GitHub. Before every push:

1. **No embedded third-party content** — never add copyrighted exam questions, book text, or licensed material to any file in this repo. The engine/data split exists specifically to prevent this.
2. **Run a copyright scan** before each phase push:
   ```bash
   grep -rin "copyright\|all rights reserved\|©\|CompTIA\|exam objectives" .
   ```
   Matches in `PLAN.md`/`CLAUDE.md` that reference the *concept* of copyright are fine — embedded question content is not.
3. **No secrets** — no API keys, tokens, or credentials committed. The AI extractor (Phase 3) will need a Claude API key; it must read from an env var or config file excluded by `.gitignore`.

---

## Project Completion Tracking Convention
- `PLAN.md` is the canonical task list — use `[x]` checkboxes and update the `## Status` table
- After completing any logical milestone, update both `PLAN.md` and the "Current Build State" section in this file
- This ensures continuity across AI sessions without re-reading all code

---

## Current Build State — 2026-03-11

**Status: Phase 3 complete. Next: Phase 4 — Documentation (README.md + DEV.md).**

| File | Done | Phase |
|------|------|-------|
| `PLAN.md` | ✅ | — |
| `CLAUDE.md` | ✅ | — |
| `engine/quiz-engine.html` | ✅ | 1 |
| `schemas/questions.schema.json` | ✅ | 2 |
| `examples/sample-questions.json` | ✅ | 2 |
| `parsers/extract-questions.pl` | ✅ | 3 |
| `parsers/secplus-parser.pl` | ✅ | 3 |
| `README.md` | ⬜ | 4 |
| `DEV.md` | ⬜ | 4 |
| `parsers/ai-extract.pl` | ⬜ | 6 |

**Next step for a new session:** Phase 4 — write `README.md` (user-focused) and `DEV.md` (developer-focused). See PLAN.md Phase 4 for full task list.

---

## Project Summary

A generalized, self-contained browser-based practice test engine. Works with any subject matter. Users supply their own question data as a JSON file; the engine handles testing, scoring, progress tracking, history, and review.

**Origin:** Derived from `c:\Code\SecurityTester\SecurityPlus.html` — a Security+ SY0-701 practice test app with 1,005 questions. That app's engine is already solid; this project generalizes it and makes it publishable (no copyrighted content embedded).

---

## Repository Structure

```
Testmaker/
├── engine/
│   └── quiz-engine.html       ← THE APP (self-contained, loads external JSON)
├── parsers/
│   ├── extract-questions.pl   ← Free regex/heuristic parser (Phase 3)
│   ├── ai-extract.pl          ← AI-powered extractor, multi-provider (Phase 6)
│   └── secplus-parser.pl      ← Reference: SecurityTester-specific parser (Phase 3)
├── schemas/
│   └── questions.schema.json  ← Formal JSON Schema for question data
├── examples/
│   └── sample-questions.json  ← 10 demo questions
├── README.md                  ← User-focused docs (Phase 4)
├── DEV.md                     ← Developer-focused docs (Phase 4)
├── PLAN.md                    ← Full project plan + task tracking
└── CLAUDE.md                  ← This file
```

---

## questions.json Schema (canonical format)

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
      "options": { "A": "...", "B": "...", "C": "...", "D": "..." },
      "correct": "B",
      "explanation": "Optional explanation text."
    }
  ]
}
```

**Key rules:**
- `meta.categories[].id` values must be integers
- `questions[].category` must match a valid `meta.categories[].id`
- `questions[].correct` must match a key in `questions[].options`
- `explanation` is optional — app handles its absence gracefully
- `meta.examInfo` is optional — if absent, exam simulation mode is disabled
- Option keys can be any string (A/B/C/D, 1/2/3, True/False, etc.)

---

## Environment
- **OS**: Windows 11 Pro, running in Git Bash (MSYS2)
- **Paths**: Use `/c/Code/Testmaker/` in bash, `C:\Code\Testmaker\` in Windows
- **Available**: Perl 5.38, browser (Chrome/Firefox/Edge)
- **NOT available**: Node.js, Python (only Windows Store alias)
- **JSON in Perl**: `use JSON;` works
- **Claude API**: Available for the extractor — use claude-sonnet-4-6 model

---

## Source App Reference (SecurityTester)

The quiz engine code lives at `c:\Code\SecurityTester\SecurityPlus.html`.
It is a ~919 KB single HTML file with all JS/CSS/questions embedded.
When porting, read `generate_html.pl` (the template is inside it) rather than the giant HTML.

Key app features to preserve:
- Home dashboard (accuracy bars, session history, study tips)
- Config screen (category filter, count, mode, shuffle, weak-only, timer)
- Test screen (progress bar, immediate/summary mode, flag button)
- Review screen (score, pass/fail, category breakdown, filterable question list)
- Exam simulation mode (weighted categories, countdown timer)
- History view
- Full localStorage persistence
- Keyboard shortcuts: 1-4/A-D select, Enter next, F flag, ←→ navigate

---

## Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Question data | External JSON, loaded by user | No copyright risk; engine is freely publishable |
| File loading | Browser File API (drag-drop + picker) | No server, works file:// |
| Build tooling | None — vanilla HTML/JS/CSS | Zero dependencies, max portability |
| AI extractor | Perl + Claude API | Consistent with SecurityTester tooling |
| GitHub publishing | Engine + schema + examples only | Safe to publish; no copyrighted content |

---

## localStorage Keys
- `tm_data_{setName}` — per-question-set stats (sessions + per-question accuracy)
- `tm_config` — last used config (file, categories, count, mode, etc.)
- `tm_last_data` — full cached question set JSON (best-effort; may fail on quota)

---

## Lessons Learned

### Architecture
- **Copyright drove the engine/data split.** The SecurityTester app embedded 1,005 book questions directly in the HTML — legally fine for personal use but unpublishable. Testmaker exists specifically because separating the engine from the data makes it safe to open-source. Never embed third-party content in the engine.
- **`examInfo` being optional was correct.** Most study sets won't need a timed exam simulation. Making it optional means the Exam Simulation button simply doesn't appear for sets without it — zero friction for simple use cases.

### JavaScript Gotchas
- **`esc()` must be a `function` declaration, not a `const` arrow.** Function declarations are hoisted to the top of scope; `const`/`let` assignments are not. Because `esc()` is called inside dynamically built `onclick="..."` HTML strings that run before the full script block finishes parsing, it must be a declaration. If converted to a const arrow, it will throw `ReferenceError` on inline handlers.
- **Category IDs use strict equality (`===`).** The JSON schema defines category `id` as an integer (e.g., `1`, not `"1"`). Mixing string and integer IDs in a question set causes `q.category === cat.id` to silently fail — questions get filtered out with no error. **Always use integers for category IDs in questions.json files.**
- **Option shuffling is value-preserving, not key-reassigning.** The shuffle algorithm swaps the *text values* behind the same letter keys (A/B/C/D), rather than renaming the keys. This keeps option labels meaningful and makes the `correct` field remapping straightforward. Do not change this to key-swapping.

### localStorage
- **Caching large question sets can hit the quota limit (~5–10 MB depending on browser).** The `tm_last_data` write is wrapped in `try/catch` — if it fails, the set stays in memory for the session only. On next page load the user will see the load screen again. This is acceptable; do not attempt to chunk or compress the data.
- **Stats are namespaced per question set** via `encodeURIComponent(meta.name)`. If a user renames their question set (changes `meta.name`), their history is effectively orphaned under the old key. Document this in DEV.md as a known limitation.

### UX Decisions
- **The "Continue →" cache banner is intentional.** Rather than silently auto-loading the last set on page open (which could confuse users who want to switch sets), the banner presents a visible, dismissible offer. This gives users control without adding friction for the common case.
- **`changeSet()` prompts before navigating.** The confirm dialog is intentional — switching sets is non-trivial (you lose the active test context). It should stay even though it feels slightly verbose.

### Schema Design
- **`explanation` intentionally optional.** Many question sources don't include explanations. The engine renders nothing (not an empty box) when the field is absent. When building question sets manually, explanations are strongly recommended but not enforced.
- **`weight` in categories is optional.** If no categories have a `weight > 0`, exam simulation distributes questions uniformly. If any category has a weight, all categories should have weights that sum to 100 — the engine doesn't validate this, it just uses proportional math.
