# Testmaker — Comprehensive Review
*Generated: 2026-03-14*

---

## Executive Summary

Testmaker is a mature, dependency-free browser-based practice test engine currently sitting at the end of Phase 7 (Docker service). The project is well-engineered, well-documented, and ready to share. Phase 7 work is complete on the `phase-7-docker-service` branch but not yet merged to `main` — that PR is the single most important pending action. Code quality is high throughout, with three targeted issues worth addressing before the branch merges: missing Docker `HEALTHCHECK`, stale CLAUDE.md tracking state, and DEV.md not yet documenting the `docker/` layer.

---

## Code Health

**Overall: Excellent.** Clean, intentional code with good separation between data and engine.

### Findings

**1. Missing HEALTHCHECK in Dockerfile — medium priority**
The server has a working `/health` route (`GET /health → 200 OK`) but the Dockerfile has no `HEALTHCHECK` directive and `docker-compose.yml` has no `healthcheck:` block. Per your CLAUDE.md standards, health checks are required on all services. Docker won't know if the Perl process is hung.

*Fix:*
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
```

**2. Missing CPU limits in docker-compose.yml — low priority**
`deploy.resources` only sets `memory: 256m`. Your standard calls for full resource limits. A malicious large PDF upload could spike CPU without a CPU cap.

*Fix:*
```yaml
deploy:
  resources:
    limits:
      memory: 256m
      cpus: '0.5'
```

**3. Container runs as root — low priority (homelab context)**
The Dockerfile uses the default Alpine root user. Not a critical risk in a single-user homelab, but best practice is to add a non-root user for any internet-facing service.

*Fix: add to Dockerfile before `CMD`:*
```dockerfile
RUN adduser -D -u 1000 testmaker
USER testmaker
```

**4. validateData() partial check — documented, intentional**
Only the first 5 questions are validated at load time (performance tradeoff). Documented in DEV.md and PLAN.md. No action required, but the schema hint in the load UI correctly warns users to validate externally for large sets.

**5. XSS handling — clean, no issues**
`esc()` (line 1143) properly escapes all 5 HTML entities. Question text uses `textContent` (line 867). Explanations use `esc()` inside `innerHTML`. `file.name` in the spinner uses `textContent`. Server-side, the X-Filename shell injection vector is correctly handled with single-quote escaping. No XSS or shell injection risk found.

---

## Documentation Health

### README.md — **Current**
Accurate to Phase 7. Docker Quick Start section leads correctly. JSON-only path documented. Parser usage and troubleshooting are solid. FAQ covers the real edge cases (history orphaning, localStorage, True/False). Minor note: the sample file says "10 demo questions" on line 85 but the actual file has 12 — update that line.

### DEV.md — **Needs minor update**
The architecture diagram and `Repository Structure` section don't include the `docker/` directory. A developer landing on `DEV.md` would have no idea `server.pl` exists or what it does.

*Add to the repo structure block:*
```
├── docker/
│   ├── Dockerfile             ← Alpine + Perl + poppler container
│   ├── docker-compose.yml     ← Port 8080, memory limit, log rotation
│   └── server.pl              ← HTTP server: GET / → engine, POST /parse → parser
```
Also add a short "Docker Service" section describing the server routes.

### PLAN.md — **Current**
Phase 7 is correctly marked pending → the Phase 7 tasks checkboxes still show `[ ]` which is accurate since the PR isn't merged. Mark them complete once the PR merges.

### CLAUDE.md — **Stale — needs update**
The "Current Build State" section still says *"Phase 5 complete. Next: Phase 6 — AI Model Integration."* Phase 7 is now complete. The file tracking table at the bottom is also missing the three new Docker files.

*Update "Current Build State" to:*
> **Status: Phase 7 complete (pending PR merge). Next: Phase 6 — AI Model Integration OR public launch promotion.**

*Add to the file table:*
```
| `docker/Dockerfile`          | ✅ | 7 |
| `docker/docker-compose.yml`  | ✅ | 7 |
| `docker/server.pl`           | ✅ | 7 |
```

---

## Log Analysis

No persistent log files present (expected — client-side SPA with no backend in normal operation).

**Docker mode:** `server.pl` emits startup messages via `print` and errors via `warn`, both captured by the json-file driver configured in `docker-compose.yml`. This is correct and sufficient for a homelab service.

**Gap: No access logging.** Successful GET and POST requests don't generate any log output. If something goes wrong ("why didn't my PDF parse?"), there's no request log to review.

*Suggested addition to `server.pl` `handle_request()` — after routing:*
```perl
warn sprintf("[%s] %s %s\n", scalar localtime, $method // 'UNKNOWN', $path // '/');
```

---

## Frontend Review

*App is not currently running — analysis is source-based.*

### Current State Assessment

**Strengths:**
- Dark mode with a coherent indigo palette (`#6366f1`) — reads professional, not generic
- Consistent card/badge/button system across all 6 views
- Schema hint on the load screen is excellent UX — users see exactly what format is needed before trying
- Responsive breakpoint at 600px works well for the grid and CTA buttons

**Gaps:**
- Category badge `<div>` elements have no `aria-label` — screen readers can't identify which category a question belongs to
- Answer options are `div` elements with `onclick` — they're not keyboard-focusable via Tab (keyboard users must use the 1-4/A-D shortcuts which are well-documented but non-obvious)
- The load screen title says "Drop a PDF or questions.json here" but when opened as `file://` PDFs are rejected — the subtitle should conditionally say "Drop a questions.json here" to avoid confusing local users
- No visual loading state on the home screen while localStorage data loads on first open

### Three Design Directions

---

#### Direction 1 — "Clean Operator"
*Safe evolution of the current identity. Same dark foundation, tightened and professionalized.*

Mood: Focused, tool-like, trusted. Feels like a developer console or a well-built SaaS dashboard.
Palette: `#0d1117` (near-black bg), `#161b22` (card), `#58a6ff` (primary blue), `#3fb950` (correct), `#f85149` (wrong)
Typography: **Inter** (headings) + **Inter** (body) — maximum readability, current tech-tool aesthetic
Appeals to: developers, IT professionals, anyone who already trusts "dark + blue"

```html
<!-- Card sample -->
<div style="background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px;
  font-family:'Inter',sans-serif;max-width:400px">
  <div style="font-size:11px;font-weight:700;color:#58a6ff;text-transform:uppercase;
    letter-spacing:.1em;margin-bottom:8px">Network+ Domain 2</div>
  <div style="font-size:16px;font-weight:600;color:#e6edf3;margin-bottom:16px">
    Which protocol operates at Layer 3?</div>
  <div style="display:flex;flex-direction:column;gap:8px">
    <div style="padding:10px 14px;border:1px solid #30363d;border-radius:6px;
      font-size:14px;color:#8b949e;cursor:pointer">A. TCP</div>
    <div style="padding:10px 14px;border:1px solid #58a6ff;border-radius:6px;
      font-size:14px;color:#58a6ff;background:rgba(88,166,255,.08);cursor:pointer">B. IP</div>
  </div>
</div>
```

---

#### Direction 2 — "Warm & Human"
*Break from pure tech tool. Approachable, encouraging, study-session energy.*

Mood: Like a well-designed notes app or flashcard tool. Warm, motivating, good for long study sessions.
Palette: `#1c1917` (warm near-black), `#292524` (card), `#f97316` (amber primary), `#4ade80` (correct), `#f87171` (wrong)
Typography: **Plus Jakarta Sans** (headings, rounded/warm) + **DM Sans** (body, readable)
Appeals to: students, certification candidates, anyone intimidated by "hacker UI"

```html
<div style="background:#292524;border:1px solid #44403c;border-radius:14px;padding:22px;
  font-family:'Plus Jakarta Sans',sans-serif;max-width:400px">
  <div style="display:flex;align-items:center;gap:8px;margin-bottom:12px">
    <span style="background:#f97316;color:#fff;font-size:11px;font-weight:700;
      padding:3px 10px;border-radius:20px">Protocols</span>
    <span style="color:#78716c;font-size:12px">Q 3 of 20</span>
  </div>
  <div style="font-size:17px;font-weight:600;color:#fafaf9;margin-bottom:18px;line-height:1.5">
    Which protocol operates at Layer 3?</div>
  <div style="display:flex;flex-direction:column;gap:10px">
    <div style="padding:12px 16px;border:2px solid #44403c;border-radius:10px;
      font-size:14px;color:#a8a29e;cursor:pointer">A. TCP</div>
    <div style="padding:12px 16px;border:2px solid #f97316;border-radius:10px;
      font-size:14px;color:#fafaf9;background:rgba(249,115,22,.1);cursor:pointer">B. IP ✓</div>
  </div>
</div>
```

---

#### Direction 3 — "Bold Editorial"
*Unexpected. High-contrast, typographically driven. Looks like a design tool, not a study app.*

Mood: Confident, almost aggressive. The kind of UI that gets screenshots on Twitter. Stands out in a portfolio.
Palette: `#09090b` (near-black), `#18181b` (card), `#a78bfa` (violet), `#ffffff` (headings), `#71717a` (muted)
Typography: **Sora** (headings — geometric, bold) + **IBM Plex Mono** (option labels — monospace nod to code culture)
Appeals to: developers building their own question sets, people who would share this with their network

```html
<div style="background:#18181b;border:1px solid #27272a;border-radius:4px;padding:24px;
  font-family:'Sora',sans-serif;max-width:400px">
  <div style="font-size:28px;font-weight:800;color:#ffffff;margin-bottom:4px;line-height:1.2">
    Which protocol<br>operates at Layer 3?</div>
  <div style="font-size:11px;color:#a78bfa;font-weight:700;letter-spacing:.15em;
    text-transform:uppercase;margin-bottom:20px;margin-top:8px">PROTOCOLS · Q3</div>
  <div style="display:flex;flex-direction:column;gap:6px;font-family:'IBM Plex Mono',monospace">
    <div style="padding:10px 16px;border-left:3px solid #3f3f46;
      font-size:13px;color:#71717a;cursor:pointer">A → TCP</div>
    <div style="padding:10px 16px;border-left:3px solid #a78bfa;
      font-size:13px;color:#a78bfa;background:rgba(167,139,250,.06);cursor:pointer">B → IP</div>
  </div>
</div>
```

---

## Feature Opportunities

### Quick Wins *(low effort, high impact)*

1. **Export session results to CSV/JSON** — At review screen, add a "Save Results" button. Single function to serialize `testState.answers` with question text. Huge for users tracking long-term progress across browsers or devices.

2. **Conditional load screen subtitle** — When `window.location.protocol === 'file:'`, change "Drop a PDF or questions.json" to "Drop a questions.json here". Eliminates a common confusion point.

3. **Add HEALTHCHECK to Dockerfile** — One-liner (documented above). Needed for production-quality container ops.

4. **Request access log in server.pl** — One `warn` line per request. Zero user-facing change, huge ops improvement.

5. **"New Test (Same Settings)" button in Review** — Current "Retake" uses same questions, "New Test" opens config. A button that re-runs with same config settings but freshly sampled pool would be the most-used flow for serious exam prep.

6. **README: fix "10 demo questions" → "12 demo questions"** — Trivial but noticeable.

---

### Medium Bets *(1–2 sprints, meaningful value)*

7. **Phase 6 — AI extractor (`parsers/ai-extract.pl`)** — Already specced in PLAN.md. The `--dry-run`, `--chunk`, and cost-transparency features are genuinely differentiating — no other free quiz tool has that. Priority after Docker merge.

8. **Multiple question set management** — Currently only one active set (the cached one). A simple "My Sets" list in localStorage, showing set name + question count + last studied date + accuracy, would make Testmaker much stickier.

9. **Question set sharing via URL hash** — Encode a small question set (or a link to a hosted JSON file) in the URL hash. Lets instructors share a question set with students via a link — no file transfer needed.

10. **Keyboard-accessible options via Tab/arrow keys** — Convert answer option `div`s to `button` elements (or add `tabindex="0"` and `role="radio"`). Unlocks accessibility for users who can't or won't learn custom shortcuts.

11. **Study streak / calendar view** — A simple heatmap of study days (like GitHub's contribution graph) on the home screen. Low implementation cost, high motivation / retention impact.

---

### Big Swings *(speculative but potentially transformative)*

12. **Browser extension** — Watches for quiz-format text on any page (Wikipedia, study guides, PDFs via browser PDF viewer) and offers a "Create Practice Test" button. Zero user friction for the extraction step.

13. **Collaborative question sets via GitHub Gist** — User pastes a Gist URL; the engine fetches and loads the JSON. Gist becomes a free, versioned hosting layer. No server required.

14. **AI-generated study tips per weak question** — After a wrong answer, a "Why?" button that POSTs the question + explanation to `/explain` (new Docker endpoint). Calls Claude API, returns a conversational explanation. Turns Testmaker into a lightweight tutor.

---

## Brand Directions

**Current brand:** "Testmaker" — functional name, no visual identity beyond inherited SecurityTester colors. Indigo + dark is competent but anonymous.

---

### Direction A — Refine *(sharpen what exists)*

Keep "Testmaker". Tighten the palette to fewer, more intentional shades. Add a simple logomark — a checkmark inside a document outline, monochromatic.

- **Palette:** `#6366f1` (primary), `#4f46e5` (hover), `#0f1117` (bg), `#1a1d2e` (card)
- **Typography:** Inter (already in system stack) — just use it explicitly rather than relying on Segoe UI
- **Tone:** Precise · Reliable · Focused
- **Brand statement:** *"The practice test engine that gets out of your way."*

---

### Direction B — Evolve *(open to new audiences)*

Rename to **"Quizcraft"** or **"Study Engine"**. Warmer tone. Appeals to educators, non-technical users, and students — not just IT cert candidates.

- **Palette:** `#f97316` (amber primary), `#1c1917` (bg), `#292524` (card), `#fafaf9` (text)
- **Typography:** Plus Jakarta Sans (headers) + DM Sans (body)
- **Tone:** Encouraging · Accessible · Practical
- **Brand statement:** *"Turn any document into a practice test. No account, no friction."*

---

### Direction C — Reimagine *(bold repositioning)*

Rename to **"Drillbit"**. Positioning: the practice tool for people who take learning seriously. Punchy, opinionated, developer-forward. The kind of tool that gets written up on HN.

- **Palette:** `#a78bfa` (violet), `#09090b` (bg), `#18181b` (card), `#ffffff` (headings)
- **Typography:** Sora (headers, geometric weight) + IBM Plex Mono (option labels)
- **Tone:** Confident · Sharp · Unconventional
- **Brand statement:** *"You bring the questions. Drillbit handles the rest."*

---

## Recommended Next Steps

Priority order — do these in sequence:

1. **Merge the Phase 7 PR** — The main deliverable is done and on a branch. Merge it. Fix the three Docker gaps (HEALTHCHECK, CPU limit, access log) in the same PR before merging.

2. **Update CLAUDE.md and DEV.md** — Bring both files current with the Docker layer. 20-minute task that pays dividends for every future session.

3. **Fix the README "10 questions" copy error** — Trivial, but it's wrong and visible to external users.

4. **Pick your next phase** — PLAN.md says Phase 6 (AI extractor) next, but Phase 7 CLAUDE.md note recommends Docker first (done). Now decide: build the AI extractor (Phase 6) or invest in UX/distribution improvements (some of the Quick Wins above).

5. **Access log + conditional load subtitle** — Both are single-line changes, no planning needed. Add them to the Phase 7 PR or as a fast follow.
