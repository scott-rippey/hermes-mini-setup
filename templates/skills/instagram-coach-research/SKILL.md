---
name: instagram-coach-research
description: Read-only Instagram methodology research — a deterministic script (ig_capture.py) harvests a coach's public posts over a date window straight from Instagram's grid feed through the agent's logged-in Chrome profile clone (captions + EVERY carousel slide, transcribed by vision in parallel) into a resumable ledger; then the agent synthesizes a methodology comparison against the KB. Trigger phrases "scrape <handle>'s instagram", "compare coaching methodologies on instagram", "instagram research on <handle>".
version: 1.0.0
author: reference build
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [Instagram, Research, Browser, Methodology, OCR]
---

# Instagram Coach Research

Builds a grounded picture of how a coach actually programs — from their public
Instagram posts — so the operator can see where their own methodology aligns and differs.
Everything is captured through the **built-in browser tools** on the agent's
**real-profile snapshot** (`browser.use_real_profile: true`, pinned to the Chrome
profile signed into the dedicated research Instagram account that follows the
target coaches). Instagram's public web and `web_extract` show only a cover slide
and a truncated caption; the logged-in browser shows everything.

**Read-only, always.** This skill never likes, follows, comments, messages,
saves, or changes anything on Instagram, never logs in or answers a 2FA
challenge, and never writes to the KB on its own.

## Preconditions (check, don't assume)

1. `browser_navigate` to `https://www.instagram.com/<handle>/` then
   `browser_snapshot`. A logged-in view shows **Following/Follow + Message**
   buttons and the post grid. A login wall, "Log in to continue", or a
   challenge/captcha page ⇒ **stop and report** — do not attempt to log in.
   the operator fixes the profile themselves (quit Chrome on the box, re-login, retry).
2. Scope from the operator (ask once, via `clarify` if anything is missing): the
   handles, the window (default **12 months**, 6 months is the acceptable
   floor).

## Procedure

### 1. Capture (deterministic — always the script, never hand-browsing)

```
python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_capture.py run <handle> --since YYYY-MM-DD
```
(`capture` and `transcribe` also run separately; `--rebuild-profile` re-clones the login.)
What it does: launches the real Chrome binary headless on a **clone of the research
account's Chrome profile** (Hermes's own real-profile flag set + Glic disabled), attaches
Playwright over CDP, opens the profile page and scrolls — Instagram's grid feed
(`PolarisProfilePostsQuery` / `…TabContentQuery_connection`, 12 posts a page) carries
every post object: code, timestamp, type, full caption, and **every carousel slide's
image URL** — so no post page is visited. Posts inside the window are upserted into the
ledger (type `post` / `carousel` / `reel`; reels = caption only, carousel videos skipped);
then every slide image is transcribed verbatim through Hermes's vision function, several
in parallel (~2 s a slide). Pinned posts older than the window are skipped, not treated
as the end. Twelve months of a daily poster ≈ a few minutes of capture + ~1 h of
transcription. The script exits 2 on `login_wall` / `rate_limited` — **stop and report**,
never work around it. **Chrome must be quit on the box** before it runs (it refuses
otherwise: the auth databases are write-locked while Chrome is open).

### 2. Verify the ledger

```
python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_ledger.py status <handle>
```
Check: oldest date ≤ the window start (or the run said `grid_exhausted`), and
`carousels_without_slide_text` is empty (re-run `transcribe` for stragglers; a slide
that failed twice carries an `error` field — mention it, don't fake text).

### 2b. Fallback only — browser tools by hand

If the script cannot run (Playwright gone, Chrome moved), the built-in browser tools can
do the same job one post at a time: `browser_navigate` the profile → collect post links →
per post read date/caption, step carousels with `browser_click` Next + `browser_get_images`,
transcribe each slide URL with `vision_analyze` (**never `browser_vision`** — the headless
snapshot cannot screenshot), `ig_ledger.py add` after every post, one failure = one post
skipped with `notes`. Expect ~7 min per carousel; use it for a handful of posts, not a year.

### 3. Report before synthesis

```
python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_ledger.py status <handle>
```
One short Slack message per handle: posts captured (by type), date range covered vs
the window asked for, slides transcribed, anything skipped (carousel videos, failed
slides) and why.

### 4. Synthesis (map-reduce — the script, then the agent)

```
python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_synthesize.py digest <handle> --since YYYY-MM-DD
python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_synthesize.py final --handles a,b --app <app-slug> --ours "<our program name>" --subject "<email subject>" --topic "<what the operator asked>"
```
`digest` turns each coach-month of the ledger into METHODOLOGY NOTES (one no-tools agent
call per month, a few in parallel, every claim cited `(date · URL)`, prescribed vs promoted
kept apart) under `<handle>/digest-YYYY-MM.md` — resumable. `final` exports the app's own
methodology docs from the KB (`--kb-hints` path substrings; narrow them to the app's methodology docs), then runs ONE agent turn that writes the comparison (executive
summary · per-coach profiles · side-by-side on each supported axis · where we align /
differ / are stronger / have blind spots, every claim cited; verbatim-quote appendix) to
`synthesis/methodology-comparison-<date>.md`, exports it with `deliverable-export`
(branded DOCX + PDF, emailed to the operator), posts the summary to Slack and prints
`FINAL_RESULT: …`. **Offer** to file the report in the KB (type `research`, under the
customer and app the operator names). The operator decides; never auto-store. Raw ledgers and digests
stay on disk, not in the KB.

## Hard rules

1. Read-only on Instagram: no follows, likes, comments, saves, DMs, no profile
   or settings pages. The research account exists only to view.
   Enforced in software too: the `social-readonly` plugin vetoes browser_click /
   browser_type / browser_press / JS eval on social hosts (fail-closed) — a block
   there is the guard working, not a bug to route around.
2. Never log in, never enter a code, never bypass a challenge. Stop and tell the operator.
3. No reel video — caption text only.
4. Stop on any rate-limit / "try again later" signal; report what was captured.
5. The ledger on disk is the only state. Never reconstruct progress from memory;
   always `next`/`status` first.
6. KB writes only on the operator's explicit say-so (standard offer-then-file gate).
7. Public content of public accounts only; no private accounts, no DMs, no
   stories/highlights (ephemeral by design — out of scope).
