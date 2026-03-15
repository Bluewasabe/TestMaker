# Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all findings from PROJECT_REVIEW.md — infrastructure, code, and documentation gaps identified after Phase 7 completion.

**Architecture:** Targeted edits to 7 existing files. No new files. All work is on branch `phase-7-docker-service` in `c:/Code/Testmaker`. Tasks 1–4 are code/infra changes; Tasks 5–7 are documentation updates.

**Tech Stack:** Perl (server.pl), HTML/JS (quiz-engine.html), Docker (Dockerfile, docker-compose.yml), Markdown (README, CLAUDE.md, DEV.md, PLAN.md)

---

## Chunk 1: Infrastructure + Code Fixes

### Task 1: Dockerfile — HEALTHCHECK + non-root user

**Files:**
- Modify: `docker/Dockerfile`

The Dockerfile is missing two things required by project standards:
1. A `HEALTHCHECK` directive that exercises the live `/health` route
2. A non-root user (currently runs everything as Alpine root)

The non-root user must own `/app` so the server process can read files.
The `HEALTHCHECK` uses `wget` (available in Alpine base without extra packages).

- [ ] **Step 1: Edit docker/Dockerfile**

Replace the current content with:

```dockerfile
FROM alpine:3.19

# Install Perl, JSON module, and poppler (pdftotext)
RUN apk add --no-cache \
    perl \
    perl-json \
    poppler-utils

# Create a non-root user
RUN adduser -D -u 1000 testmaker

# Copy application files
COPY parsers/   /app/parsers/
COPY engine/    /app/engine/
COPY examples/  /app/examples/
COPY schemas/   /app/schemas/
COPY docker/server.pl /app/server.pl

RUN chown -R testmaker:testmaker /app

WORKDIR /app

USER testmaker

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["perl", "server.pl"]
```

- [ ] **Step 2: Verify the edit looks correct** (read the file back)

- [ ] **Step 3: Commit**

```bash
cd c:/Code/Testmaker
git add docker/Dockerfile
git commit -m "Add HEALTHCHECK and non-root user to Dockerfile"
```

---

### Task 2: docker-compose.yml — CPU limits

**Files:**
- Modify: `docker/docker-compose.yml`

Add `cpus: '0.5'` to the existing `deploy.resources.limits` block alongside the existing `memory: 256m`.

- [ ] **Step 1: Edit docker/docker-compose.yml**

```yaml
services:
  testmaker:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    container_name: testmaker
    ports:
      - "${PORT:-8080}:8080"
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    deploy:
      resources:
        limits:
          memory: 256m
          cpus: '0.5'
```

- [ ] **Step 2: Verify the edit looks correct**

- [ ] **Step 3: Commit**

```bash
cd c:/Code/Testmaker
git add docker/docker-compose.yml
git commit -m "Add CPU limit to docker-compose resource constraints"
```

---

### Task 3: server.pl — request access logging

**Files:**
- Modify: `docker/server.pl`

Add one `warn` call in `handle_request()` immediately after the method/path are parsed — before the routing block. This emits an access-log line to stderr, which the json-file Docker log driver captures.

Format: `[Tue Mar 14 12:00:00 2026] GET /`

- [ ] **Step 1: Edit docker/server.pl**

Find the line:
```perl
    my ($method, $path, $proto) = split /\s+/, $request_line, 3;
    $path =~ s/[?#].*//;   # strip query string / fragment
```

Add the warn line immediately after (before the routing block):
```perl
    my ($method, $path, $proto) = split /\s+/, $request_line, 3;
    $path =~ s/[?#].*//;   # strip query string / fragment

    warn sprintf("[%s] %s %s\n", scalar localtime, $method // '-', $path // '/');
```

- [ ] **Step 2: Verify the edit looks correct**

- [ ] **Step 3: Commit**

```bash
cd c:/Code/Testmaker
git add docker/server.pl
git commit -m "Add request access logging to server.pl"
```

---

### Task 4: quiz-engine.html — conditional load subtitle

**Files:**
- Modify: `engine/quiz-engine.html`

When opened as `file://`, PDF drops are rejected with an error. But the drop zone currently always says "Drop a PDF or questions.json here", which misleads local users into trying to drop a PDF.

Fix: detect `file://` protocol on page load and swap the drop zone title + subtitle to JSON-only language.

- [ ] **Step 1: Find the existing tryRestoreCache() call**

In `quiz-engine.html`, find the line near the bottom of the `<script>` block:
```js
tryRestoreCache();
```

- [ ] **Step 2: Add the conditional subtitle fix after tryRestoreCache()**

Add immediately after `tryRestoreCache();`:
```js
// When opened as a local file, PDF parsing is unavailable — update the drop zone text
if (window.location.protocol === 'file:') {
  document.getElementById('drop-title').textContent = 'Drop a questions.json here';
  document.getElementById('drop-sub').textContent   = 'or click to browse — PDF parsing requires the Docker service';
}
```

- [ ] **Step 3: Verify the change is correct**

- [ ] **Step 4: Commit**

```bash
cd c:/Code/Testmaker
git add engine/quiz-engine.html
git commit -m "Show JSON-only drop text when opened as file:// (PDF requires Docker)"
```

---

## Chunk 2: Documentation Updates

### Task 5: README.md — fix question count

**Files:**
- Modify: `README.md`

Line 85 says "10 demo questions" but the sample file has 12 questions (validated in Phase 5).

- [ ] **Step 1: Edit README.md**

Find:
```
`examples/sample-questions.json` contains 10 demo questions across two categories.
```

Replace with:
```
`examples/sample-questions.json` contains 12 demo questions across two categories.
```

- [ ] **Step 2: Commit**

```bash
cd c:/Code/Testmaker
git add README.md
git commit -m "Fix sample question count: 10 -> 12 in README"
```

---

### Task 6: CLAUDE.md — update Phase 7 tracking state

**Files:**
- Modify: `CLAUDE.md`

Two stale sections:
1. "Current Build State" header still says Phase 5 complete, Phase 6 next
2. File tracking table missing Docker files

- [ ] **Step 1: Update "Current Build State" header**

Find:
```
**Status: Phase 5 complete. Next: Phase 6 — AI Model Integration (optional enhancement).**
```

Replace with:
```
**Status: Phase 7 complete (PR open on phase-7-docker-service branch). Next: Phase 6 — AI Model Integration OR public launch.**
```

- [ ] **Step 2: Update the date**

Find:
```
## Current Build State — 2026-03-11
```

Replace with:
```
## Current Build State — 2026-03-14
```

- [ ] **Step 3: Add Docker files to the tracking table**

Find the last row in the file tracking table:
```
| `tests/compare-secplus.pl`      | ✅ | 5 |
```

Replace with:
```
| `tests/compare-secplus.pl`      | ✅ | 5 |
| `docker/Dockerfile`             | ✅ | 7 |
| `docker/docker-compose.yml`     | ✅ | 7 |
| `docker/server.pl`              | ✅ | 7 |
```

- [ ] **Step 4: Update "Next step for a new session" note**

Find:
```
**Next step for a new session:** Phase 7 — Docker service.
```
(this line extends to the end of that paragraph)

Replace the entire paragraph with:
```
**Next step for a new session:** Phase 7 PR is open on `phase-7-docker-service`. Merge it. Phase 6 (AI extractor `parsers/ai-extract.pl`) is next. See PLAN.md Phase 6 for full spec. Alternatively: Quick Win features from PROJECT_REVIEW.md (export results, "New Test Same Settings" button).
```

- [ ] **Step 5: Commit**

```bash
cd c:/Code/Testmaker
git add CLAUDE.md
git commit -m "Update CLAUDE.md: Phase 7 complete, add Docker files to tracking table"
```

---

### Task 7: DEV.md — document the docker/ layer

**Files:**
- Modify: `DEV.md`

DEV.md's architecture section has no mention of `docker/`. A developer reading DEV.md has no idea `server.pl` exists or what routes it exposes.

Two changes needed:
1. Add `docker/` to the repository structure block
2. Add a "Docker Service" section after the "Data flow" section

- [ ] **Step 1: Update repository structure block**

Find in the `### quiz-engine.html` section the code block:
```
Testmaker/
├── engine/
│   └── quiz-engine.html       ← The entire app — one self-contained HTML file
├── parsers/
│   ├── extract-questions.pl   ← Free heuristic parser (Phase 3, patched Phase 5)
│   └── secplus-parser.pl      ← Reference parser (SecurityTester-specific, kept for reference)
├── schemas/
│   └── questions.schema.json  ← Formal JSON Schema for question data
├── examples/
│   └── sample-questions.json  ← 12 demo questions (validated Phase 5)
├── tests/
│   ├── test-inline-answers.txt  ← Parser test: inline Answer: X format
│   ├── test-answer-key.txt      ← Parser test: separate answer key section
│   ├── test-truefalse.txt       ← Parser test: bare True/False options
│   └── compare-secplus.pl       ← Comparison: general vs secplus-parser vs reference
├── README.md                  ← User-focused docs (Phase 4)
├── DEV.md                     ← This file
├── PLAN.md                    ← Full project plan + task tracking
└── CLAUDE.md                  ← AI session context
```

Replace with the same block plus the `docker/` entry (add before `README.md`):
```
Testmaker/
├── engine/
│   └── quiz-engine.html       ← The entire app — one self-contained HTML file
├── parsers/
│   ├── extract-questions.pl   ← Free heuristic parser (Phase 3, patched Phase 5)
│   └── secplus-parser.pl      ← Reference parser (SecurityTester-specific, kept for reference)
├── schemas/
│   └── questions.schema.json  ← Formal JSON Schema for question data
├── examples/
│   └── sample-questions.json  ← 12 demo questions (validated Phase 5)
├── tests/
│   ├── test-inline-answers.txt  ← Parser test: inline Answer: X format
│   ├── test-answer-key.txt      ← Parser test: separate answer key section
│   ├── test-truefalse.txt       ← Parser test: bare True/False options
│   └── compare-secplus.pl       ← Comparison: general vs secplus-parser vs reference
├── docker/
│   ├── Dockerfile             ← Alpine + Perl + poppler; non-root user; HEALTHCHECK
│   ├── docker-compose.yml     ← Port 8080, memory + CPU limits, log rotation
│   └── server.pl              ← HTTP server: GET / → engine, POST /parse → parser
├── README.md                  ← User-focused docs (Phase 4)
├── DEV.md                     ← This file
├── PLAN.md                    ← Full project plan + task tracking
└── CLAUDE.md                  ← AI session context
```

- [ ] **Step 2: Add Docker Service section**

Find the line:
```
### Data flow
```

After the entire "Data flow" mermaid block (ends with the closing ` ``` ` of the mermaid diagram, then `**State:**` paragraph), find:

```
---

## questions.json Schema
```

Insert a new section before that divider:

```markdown
---

## Docker Service

The optional Docker service (`docker/`) bundles the Perl runtime and `pdftotext` (Poppler) so non-technical users can drop a PDF and get a working practice test without any local installs.

### Architecture

```
git clone → docker compose up → http://localhost:8080 → drop PDF → test starts
```

A single Alpine container runs `docker/server.pl` — a minimal Perl HTTP server with four routes:

| Method | Path | Response |
|--------|------|----------|
| GET | `/` | Serves `engine/quiz-engine.html` |
| GET | `/sample` | Serves `examples/sample-questions.json` |
| GET | `/schema` | Serves `schemas/questions.schema.json` |
| GET | `/health` | `200 OK` (for container health checks) |
| POST | `/parse` | Runs `parsers/extract-questions.pl` on uploaded file; returns `questions.json` |

### POST /parse request format

```
Content-Type: application/pdf   (or text/plain, text/html)
X-Filename:   original-name.pdf  (used to derive the question set name)
Body:         raw file bytes (max 50 MB)
```

Response on success: `questions.json` body with headers:
- `X-Parse-Warnings: true/false`
- `X-Review-Count: N` (number of `[REVIEW]`-flagged questions)

### Running locally

```bash
docker compose -f docker/docker-compose.yml up
# open http://localhost:8080
```

### quiz-engine.html PDF detection

When served over `http://`, the engine detects PDF/TXT drops and POSTs to `/parse` automatically. When opened as `file://`, PDF drops show a friendly error — JSON-only loading is still available.

```
```

- [ ] **Step 3: Commit**

```bash
cd c:/Code/Testmaker
git add DEV.md
git commit -m "Document docker/ layer in DEV.md: repo structure + Docker Service section"
```

---

### Task 8: PLAN.md — mark Phase 7 tasks complete

**Files:**
- Modify: `PLAN.md`

Phase 7 tasks are still shown as `[ ]` (pending). All have been implemented. Mark them done and add Phase 7 Lessons Learned.

- [ ] **Step 1: Mark all Phase 7 task checkboxes complete**

In the `### Tasks` section under Phase 7, replace every `- [ ]` with `- [x]`:

```markdown
- [x] Write `docker/Dockerfile`
- [x] Write `docker/docker-compose.yml`
- [x] Write `docker/server.pl` (IO::Socket::INET, single-process, handles GET + POST)
- [x] Add PDF detection + `/parse` fetch to `engine/quiz-engine.html`
- [x] Test full flow: `docker compose up` → drop PDF → questions load
- [x] Update README: Docker quick-start section above existing Getting Started
- [x] Copyright scan
- [x] PR
```

- [ ] **Step 2: Add Phase 7 Lessons Learned**

Find:
```
### Phase 7 — Lessons Learned
> _To be filled in when Phase 7 is complete._
```

Replace with:
```
### Phase 7 — Lessons Learned

**Single-process fork model is sufficient for a personal tool.**
`IO::Socket::INET` + `fork()` handles one request per child process. No async, no threads. For a homelab tool with one user at a time this is ideal — simple, debuggable, no CPAN event-loop dependencies.

**`tempfile(UNLINK => 1)` is reliable cleanup but requires `close` before exec.**
`File::Temp` marks temp files for deletion when the handle goes out of scope. The temp input file must be explicitly `unlink`ed after the parser runs (since the child process opened it via shell, not the Perl filehandle). Letting UNLINK handle it would leave the file until the child exits — fine in practice but explicit `unlink` is cleaner.

**Shell single-quote escaping is correct for Alpine.**
User-supplied X-Filename header goes into a shell command. The pattern `s/'/'\\''/g` (escape each single quote as `'\''`) correctly neutralizes shell injection inside single-quoted strings. This is safe inside the Alpine container where the only shell is `/bin/sh` (ash).

**quiz-engine.html protocol detection for PDF routing.**
`window.location.protocol === 'file:'` correctly distinguishes the local-file case from the Docker-served case. PDF drops in `file://` mode now show a helpful error with Docker setup instructions. The drop zone title is also conditionally updated on load to avoid showing "Drop a PDF" when PDFs aren't supported.

**HEALTHCHECK needs `wget`, not `curl`.**
Alpine base image includes `wget` but not `curl`. The HEALTHCHECK directive must use `wget -qO-` rather than `curl -sf`. Adding `curl` as a dependency would be unnecessary.
```

- [ ] **Step 3: Update the Status table — mark Phase 7 done**

Find:
```
| 7 | Docker service — PDF-first UX for non-technical users | ⬜ Pending |
```

Replace with:
```
| 7 | Docker service — PDF-first UX for non-technical users | ✅ Done |
```

- [ ] **Step 4: Update "Last updated" date**

Find:
```
**Last updated: 2026-03-11** *(Phase 5 complete)*
```

Replace with:
```
**Last updated: 2026-03-14** *(Phase 7 complete)*
```

- [ ] **Step 5: Commit**

```bash
cd c:/Code/Testmaker
git add PLAN.md
git commit -m "Mark Phase 7 complete in PLAN.md, add lessons learned"
```

---

## Final Step: Push branch

After all tasks complete:

```bash
cd c:/Code/Testmaker
git push origin phase-7-docker-service
```

Then verify the PR at: https://github.com/Bluewasabe/TestMaker/pulls
