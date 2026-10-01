---
name: instagram-coach-research
description: Read-only Instagram methodology research — enumerate a coach's public posts over a date window through the agent's own logged-in browser profile, capture captions and EVERY carousel slide's text (OCR via vision), checkpoint to a resumable ledger, then synthesize a methodology comparison against the KB. Trigger phrases "scrape <handle>'s instagram", "compare coaching methodologies on instagram", "instagram research on <handle>".
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
   floor), and the batch size per turn (default **10 posts**).

## Procedure

### 1. Enumerate the grid (once per handle, resumable)

- On the profile page, `browser_snapshot`, collect every post link
  (`/<handle>/p/<id>/` and `/<handle>/reel/<id>/`; pinned posts first — keep
  them, they're still that coach's content). Collaborator reposts show as
  `/<otherhandle>/p/...` — keep those too, they're on this grid by the coach's
  choice.
- `browser_scroll` down and snapshot again until no new links appear **or** the
  queue already covers more posts than the window plausibly holds (dates are
  only visible on post pages, so the window is enforced in step 2).
- Persist the queue in grid order (newest first):
  ```
  echo '<json list of urls>' | python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_ledger.py queue <handle>
  ```

### 2. Capture posts, one at a time, checkpointing each

```
python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_ledger.py next <handle> <batch>
```
For each URL:
1. `browser_navigate` → `browser_snapshot`. Read the **date** (the post's time
   element — the snapshot shows it as text like "September 20" or an absolute
   date; older than a year shows the year), the **caption** (the author's own
   text block at the top of the comments column — all of it, expand "more" if
   shown), and the **type**: `reel` if the URL has `/reel/` or the page shows a
   video player; `carousel` if a "Next" control / slide dots are present;
   otherwise `post`.
2. **Window check:** if the date is older than the window start, record nothing,
   stop the batch, and note "window reached" — grid order is chronological, so
   everything after it is older too. (Pinned posts break this rule: if one of
   the first three posts is older than the window, skip it and continue.)
3. **Reels:** capture caption + hashtags only. **Never download, play, or
   transcribe the video** (operator's rule).
4. **Carousels:** for every slide, in order: `browser_get_images` → take the
   current slide's image URL (the large `instagram.f*.fbcdn.net` image that
   changed since the last slide; skip avatars/icons), then `browser_click` the
   **Next** button and repeat until Next is gone. Then run `vision_analyze` on
   each slide image with: *"Transcribe ALL text on this image verbatim,
   preserving line breaks and list structure. If there is a table, chart, or
   diagram, describe it in one or two precise sentences after the text. Output
   only the transcription."* — the paragraphs matter, not just headlines.
   **Use `vision_analyze` with the image URL. Never `browser_vision` or any
   screenshot** — the headless snapshot browser has no viewport to screenshot
   ("Cannot take screenshot with 0 width") and the slide image is already a URL.
5. **Single-image posts:** one slide, same vision step.
6. Record immediately:
   ```
   echo '{"url":"…","date":"YYYY-MM-DD","type":"carousel","caption":"…","hashtags":["…"],"slides":[{"index":1,"image_url":"…","text":"…"}]}' \
     | python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_ledger.py add <handle>
   ```
   The ledger upserts by URL, so a re-run of a half-captured post is safe.
7. **One failure is one post, not the batch.** If a tool call errors on a post
   (image fetch, vision, a missing Next button), retry it once; if it still
   fails, `add` the post with what you have plus `"notes": "<what failed>"` and
   move to the next URL. Only a login wall, a rate-limit page, or the browser
   itself refusing to start ends the batch early.
8. Pace like a person: one post at a time, no parallel sessions, and if
   Instagram answers with "Please wait a few minutes", "Try again later", a
   challenge page, or repeated empty snapshots, **stop the batch and report** —
   never hammer through it.

### 3. End of each batch — report, don't drift

```
python ~/.hermes/skills/productivity/instagram-coach-research/scripts/ig_ledger.py status <handle>
```
One short Slack message: posts captured so far (by type), oldest date reached vs
the window start, how many remain in the queue, anything skipped and why. Then
either continue with the next batch (if the operator said "run it all" and the turn's
budget allows) or stop and wait for "continue".

### 4. Synthesis (when the window is covered, or the operator says enough)

1. `report <handle>` for each coach → read the markdown (long; page through it
   with `read_file` if needed, it lives at `~/<outputs>/ig-research/<handle>/` (the skill's ledger dir; the agent's outputs folder)).
2. Pull the operator's own documented approach from the KB — the app's synced docs
   (`mcp_rag search` scoped to the app/customer the operator names) — and ground every "we align /
   we differ" claim in a specific KB passage.
3. Produce the comparison the operator asked for (weekly architecture, running volume
   and intensity distribution, strength method, compromised running, station
   work, progression and testing, recovery, individualization — only the axes
   the captured content actually supports; say plainly where a coach's posts
   are silent). Quote slide text verbatim where it carries the point, cite the
   post URL and date after each claim, and separate **what they prescribe**
   from **what they promote**.
4. Deliver via `deliverable-export` (branded DOCX/PDF to the outputs folder,
   emailed to the operator) and summarize in Slack.
5. **Offer** to file the report in the KB (type `research`, under the customer
   and app the operator names). The operator decides; never auto-store. Raw ledgers stay on
   disk, not in the KB.

## Hard rules

1. Read-only on Instagram: no follows, likes, comments, saves, DMs, no profile
   or settings pages. The research account exists only to view.
2. Never log in, never enter a code, never bypass a challenge. Stop and tell the operator.
3. No reel video — caption text only.
4. Stop on any rate-limit / "try again later" signal; report what was captured.
5. The ledger on disk is the only state. Never reconstruct progress from memory;
   always `next`/`status` first.
6. KB writes only on the operator's explicit say-so (standard offer-then-file gate).
7. Public content of public accounts only; no private accounts, no DMs, no
   stories/highlights (ephemeral by design — out of scope).
