# Testmaker

A self-contained, browser-based practice test engine. Works with any subject — you bring your own question data as a JSON file; the engine handles testing, scoring, progress tracking, and history.

No server. No install. No internet required after download. Open `engine/quiz-engine.html` directly in your browser.

---

## Getting Started

### 1. Open the app

Download or clone this repository, then open `engine/quiz-engine.html` in any modern browser (Chrome, Firefox, or Edge).

No web server is needed — the file runs from your local disk.

### 2. Load a question set

On the welcome screen, either:
- **Drag and drop** a `.json` question file onto the page, or
- Click **Load Question Set** and pick a file.

The app ships with a working demo file at `examples/sample-questions.json` — use it to try things out immediately.

### 3. Start a test

After loading a file you'll see your question set's name, category list, and question count. Click **Configure Test** to set up your session, then **Start Test**.

---

## Features

| Feature | Details |
|---------|---------|
| **Immediate feedback** | See correct/incorrect + explanation right after each answer |
| **Summary mode** | Review all answers at the end (exam simulation style) |
| **Category filter** | Focus on specific topics |
| **Weak-question filter** | Automatically target questions you've missed most often |
| **Shuffle** | Randomize question order and/or answer option order |
| **Timer** | Optional per-question countdown |
| **Exam simulation** | Timed, weighted, pass/fail exam (requires `examInfo` in your question set) |
| **Progress tracking** | Per-category accuracy bars, per-question history |
| **Session history** | All past test sessions saved locally |
| **Keyboard shortcuts** | `1`–`4` or `A`–`D` to select, `Enter` to advance, `F` to flag, `←`/`→` to navigate |

All data is saved in your browser's localStorage — no account or cloud needed.

---

## Getting or Creating Question Sets

### Option A — Use the sample file (instant)

`examples/sample-questions.json` contains 10 demo questions across two categories. Load it to explore all app features.

### Option B — Write a question set manually

Create a `.json` file following this structure:

```json
{
  "meta": {
    "name": "My Study Set",
    "description": "Optional description",
    "version": "1.0",
    "author": "Optional",
    "categories": [
      { "id": 1, "name": "Category One" },
      { "id": 2, "name": "Category Two" }
    ]
  },
  "questions": [
    {
      "id": "cat1_q1",
      "category": 1,
      "question": "What color is the sky?",
      "options": { "A": "Red", "B": "Blue", "C": "Green", "D": "Yellow" },
      "correct": "B",
      "explanation": "The sky appears blue due to Rayleigh scattering."
    }
  ]
}
```

See `DEV.md` for the full field reference and annotated schema.

### Option C — Parse an existing document (free, no API key)

If you already have a document that contains multiple-choice or True/False questions — a study guide, practice test book, or exported quiz — the included parser reads it and converts the existing questions to a valid question file.

> **Important:** The parser *extracts* questions that are already written in your document. It does not generate or invent new questions. Your document must contain the questions, answer options, and (ideally) an answer key.

**Requirements:** Perl 5.10+ (pre-installed on macOS and most Linux systems; Windows users can use [Strawberry Perl](https://strawberryperl.com/))

**PDF support:** requires `pdftotext` from [Poppler](https://poppler.freedesktop.org/) to be on your PATH.

```bash
# Basic usage — outputs to stdout
perl parsers/extract-questions.pl my-study-guide.txt

# Write directly to a file
perl parsers/extract-questions.pl my-study-guide.txt -o my-questions.json

# Set a name and author
perl parsers/extract-questions.pl my-study-guide.txt \
  -n "Network+ Practice" -a "Jane Smith" -o network.json
```

The parser detects numbered questions, lettered options, answer keys, explanations, and chapter/section headings automatically. Questions it isn't confident about are flagged on stderr and marked in the output for manual review.

### Option D — AI-powered parser (future — Phase 6)

A Perl script (`parsers/ai-extract.pl`) that sends document text to a large language model is planned for Phase 6. It will handle messy or inconsistently formatted documents that the regex parser struggles with. See `PLAN.md` for details.

---

## Switching Question Sets

Click **Load Different Set** on the home dashboard. You'll be prompted to confirm (switching clears the active test session). Your history for the previous set is preserved under its own name.

---

## FAQ

**Q: Does the app connect to the internet?**
No. Everything runs in your browser. No data is sent anywhere.

**Q: Where is my progress saved?**
In your browser's `localStorage`. Clearing browser data or using a different browser will lose your history.

**Q: My question set was rejected. Why?**
The app validates your JSON against a schema on load. Open the browser console (F12 → Console) for a detailed error message — it will tell you exactly which field is missing or invalid.

**Q: Can I use True/False questions?**
Yes. Set `options` to `{ "True": "True", "False": "False" }` (or any two-option object) and `correct` to the matching key.

**Q: My history disappeared after renaming my question set.**
History is stored under the question set's `meta.name`. If you change that field, the app treats it as a new set. Your old history is still in localStorage under the old name — restore the original name to recover it.

**Q: Can I use this with more than 4 answer options?**
Yes, any number of options is supported. Keys can be A/B/C/D, 1/2/3, or any strings.

**Q: The parser produced wrong answers. What do I do?**
The free parser is heuristic — it does its best with imperfect input. Open the output JSON in a text editor and fix any incorrect `correct` values or question text manually. Check stderr output for lines marked `[REVIEW]`.
