---
name: podcast-research
description: Any-podcast research — a deterministic script (pod_capture.py) resolves a show (RSS / Apple Podcasts / Podcast Index link) to its feed, downloads every episode in a date window and gets a TEXT transcript for each (publisher transcript from the feed when one exists, else local faster-whisper on the box — no cloud, no API) into a resumable ledger; then each episode is distilled in a fresh model context against {{OPERATOR_FIRST_NAME}}'s keep/skip BRIEF, and one final agent turn merges the notes into a synthesis (optionally compared with our own app docs from the KB). Trigger phrases "get me this podcast's transcripts", "distill <podcast>", "podcast research on <show>", "what does <podcast> say about <topic>".
version: 1.0.0
author: {{OPERATOR_ORG}}
license: proprietary
platforms: [macos]
metadata:
  hermes:
    tags: [Podcast, Research, Transcription, Whisper, Methodology, HYROX]
---

# Podcast Research

Turn a podcast's back catalogue into distilled, cited notes and one synthesis — for any
show, steered entirely by {{OPERATOR_FIRST_NAME}}'s brief. No site is clicked: a podcast's RSS feed already
lists every episode with its audio file, and the directories (Apple, Podcast Index) only
mirror that feed. Transcripts come from the feed when the publisher ships them, otherwise
from local speech-to-text on this box (faster-whisper `large-v3-turbo`, CPU; ~13 min per
hour of audio — a year of a weekly hour-long show ≈ one overnight). Everything lives under
`~/{{AGENT_SLUG}}-outputs/podcast-research/<show>/`.

**Why not Apple's or Spotify's transcripts?** They exist only inside their apps (Apple's
cache is encrypted and evicted since macOS 14.4/15; the only route is a private API with a
debugger-extracted signature; Spotify exposes nothing). Local transcription is just as
accurate, works for every host, and nothing can revoke it.

## Procedure

### 0. Get the brief FIRST (one `clarify` question at a time — never a batch)

Before any distillation, write {{OPERATOR_FIRST_NAME}}'s brief to `<show>/brief.md` from
`references/brief-template.md`: purpose, KEEP topics, SKIP topics, how to treat claims.
Capture (step 1) needs no brief and can start immediately; ask for the brief while it runs.
Reuse an existing brief if {{OPERATOR_FIRST_NAME}} says "same as last time".

### 1. Capture (deterministic — always the script, never hand-browsing)

```
python ~/.hermes/skills/productivity/podcast-research/scripts/pod_capture.py search "<show name>"
python ~/.hermes/skills/productivity/podcast-research/scripts/pod_capture.py resolve <url>
python ~/.hermes/skills/productivity/podcast-research/scripts/pod_capture.py run <show-slug> --feed <url> --since YYYY-MM-DD [--until …] [--limit N] [--keep-audio]
python ~/.hermes/skills/productivity/podcast-research/scripts/pod_capture.py status <show-slug>
```
`search` finds a show by name through Apple's keyless search API (no browser) and prints
the candidates with their feed URLs — show them and let the operator pick unless one matches
exactly. `resolve` / `run` accept ONLY a Podcast Index page, an Apple Podcasts page, or a
URL that actually serves RSS; anything else is refused. `run` resolves the link to the RSS feed, writes every in-window episode to
`<show>/episodes.jsonl` (`queued` → `done` / `failed`, resumable — re-run anytime),
downloads each MP3, transcribes it (or downloads the publisher's `<podcast:transcript>`),
applies `<show>/glossary.json` (misheard-word fixes, e.g. "High Rocks" → HYROX; the raw
transcript is kept as `.raw.txt`), writes `<show>/transcripts/<date>-<title>.md` with
`[mm:ss]` lines, and deletes the audio. A full back-catalogue run is HOURS: launch it
detached (`nohup … > <show>/capture.log 2>&1 &`), tell {{OPERATOR_FIRST_NAME}} it's running, report
`status` when asked or when it finishes — never sit in a turn waiting on it.
`--limit 1` first on a new show to eyeball one transcript; add mishearings to
`glossary.json` and `reglossary <show>` re-applies it to every transcript.

### 2. Verify

`status` shows counts and any `failed` rows (with the error). Open one transcript: names
and sport terms spelled right? Speaker meaning intact? Fix the glossary before step 3.

### 3. Distill — one episode per fresh context

```
python ~/.hermes/skills/productivity/podcast-research/scripts/pod_distill.py episode <show-slug> --brief <show>/brief.md --show-name "<title> (hosts …)"
```
One no-tools model call per episode (the show name + hosts go in the prompt so speakers are named) (3 in parallel), the brief in every prompt; output
`<show>/notes/<date>-<title>.md` — headings per the brief, every claim cited
`(date · mm:ss)`, prescribed vs mentioned kept apart, "Episode in one breath" + "Worth
stealing". Resumable; a FAILED episode just re-runs.

### 4. Synthesis — one agent turn

```
python ~/.hermes/skills/productivity/podcast-research/scripts/pod_distill.py final <show-slug> --brief <show>/brief.md --subject "<email subject>" --topic "<what {{OPERATOR_FIRST_NAME}} asked>" [--app <app-slug> --ours "<our program>"]
```
Runs ONE tool-enabled turn that reads every notes file (and, with `--app`, our own
methodology docs exported from the KB) and writes `<show>/synthesis/<show>-synthesis-<date>.md`
— executive summary · recurring themes with the strongest cited evidence · contradictions ·
(align / differ / stronger / blind spots vs our program when `--app`) · ranked "Worth
stealing" · verbatim-quote appendix — then `deliverable-export` (branded PDF, no DOCX,
emailed to {{OPERATOR_FIRST_NAME}}; md + pdf copied to `deliverables/`), a Slack summary, and `FINAL_RESULT: …`. **Offer** to file the synthesis
in the KB (type `research`, scope {{OPERATOR_FIRST_NAME}} names). {{OPERATOR_FIRST_NAME}} decides; never auto-store.
Transcripts and notes stay on disk, not in the KB.

**Deliverable = two files per show** in `~/{{AGENT_SLUG}}-outputs/podcast-research/deliverables/`:
`<show>-synthesis-<date>.md` (for the operator's research store) and the branded `.pdf` (for
reading). Notes and transcripts are internal scaffolding — kept on disk, never part of the
deliverable (the operator wants signal, not bulk, in the store). **Several shows unattended:** `scripts/pod_queue.sh <queue.txt> <brief.md> [--final]`
(queue lines `slug|feed|show name (hosts)`; capture → distill [→ synthesis] per show, resumable;
launch with nohup, report the log on request).

## Hard rules

1. Sources are locked: a show is found by `search` (Apple's keyless API) or given as a
   Podcast Index page, an Apple Podcasts page, or an RSS URL — nothing else, and no
   browser. Audio comes from the feed's own enclosure URLs (what every podcast app
   downloads); never scrape a player page, never log in, never use Apple/Spotify private APIs.
2. Transcription is local; no transcript or audio leaves the box except through the
   model calls in steps 3–4 (the same provider every other skill uses).
3. The ledger on disk is the only state — always `status` first, never reconstruct
   progress from memory.
4. Long runs are detached and reported on, never awaited inside a turn.
5. KB writes only on {{OPERATOR_FIRST_NAME}}'s explicit say-so (standard offer-then-file gate).
6. Public podcasts only; a paywalled/private feed is out of scope unless {{OPERATOR_FIRST_NAME}} provides it.
