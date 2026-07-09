# Meeting-report authoring spec

Everything the agent needs to author consistently excellent meeting reports from Granola data (or any meeting-notes MCP with the same three capabilities). SKILL.md owns the operational loop (select → pull → author → render → hand off → file); this doc owns the CONTENT: what a report contains, in whose voice, under what accuracy rules.

Output style rule for everything you generate: use a single hyphen "-", never an em dash or en dash.

---

## 1. Prerequisites

- The meeting-notes MCP connected, exposing: `list_meetings`, `get_meetings` (AI summary), `get_meeting_transcript` (full transcript).
- Node.js (render.js uses only built-ins - no npm install).
- The output folder with two subfolders: `markdown/`, `html/` (render.js creates them).

---

## 2. What you produce, and naming

For each meeting, two paired files sharing one base name: `YYYY-MM-DD - <meeting title>`.

| Output | Folder | Role |
|--------|--------|------|
| `.md` (clean structured) | `markdown/` | Knowledge-base copy (searchable) |
| `.html` (email-safe fragment) | `html/` | Rides the morning brief inline |

- Date is the meeting date, not today's.
- Sanitize filename-illegal characters (`/ \ : * ? " < > |`) to a space and collapse repeats. The `w/` in a title becomes `w`.

---

## 3. Inputs and data shape

- `list_meetings(time_range | custom_start/custom_end)` -> meeting IDs and exact titles.
- `get_meetings([id])` -> the provider's AI summary plus metadata. The summary is decent but subject-clustered in the order topics came up, with no stable structure and the reasoning flattened.
- `get_meeting_transcript(id)` -> the full verbatim transcript.

Combine BOTH. Most of the added value lives in transcript detail the summary compressed away (reasoning, decisions, memorable quotes).

Hard limits to respect:
- No timestamps in the transcript, so "Key Moments" are ordered by sequence, never time-coded.
- The participants field usually lists only the owner. Do not present a verified roster.
- Heavy speech-to-text errors on names and jargon. Normalize via the glossary (Section 7 + the master glossary).

---

## 4. Counterpart and speaker attribution (critical)

The transcript labels speakers only `Me:` / `Them:`. `Me` = the note owner ({{OPERATOR_FIRST_NAME}}). `Them` = everyone who is not the owner.

- Counterpart comes from the meeting title, which ends `w/ <Name>` (or `with <Name>`). The owner sets this deliberately, so for a 1:1 `Them` reliably maps to that name - use it confidently in the body. The only caveat needed is one neutral line that the name came from the title.
- Record `counterpart` and `counterpart_inferred: true` in front-matter.
- No name in the title -> counterpart `unknown`; write generically ("the other participant"). Do not guess.
- Multi-person / group call -> `Them` is a merged group; say "the group" / "participants".
- Some transcripts arrive with AssemblyAI-style `Speaker A` / `Speaker B`. Then do not assume which is the owner; infer from context/title.
- In-person recordings (one device) often label everything `Me` and blend both voices, and the provider summary can mis-attribute one person's background to the other. Attribute BY CONTENT (who would plausibly say it), add one brief neutral line that it was in-person so speakers are inferred, and do not over-hedge.

---

## 5. Content template

Author this once as the content JSON (see `samples/sample-meeting.json`); it feeds both the Markdown and the HTML. Omit any section that genuinely has no content rather than padding it.

Front-matter fields (Markdown copy):

```yaml
---
title: <meeting title>
date: <YYYY-MM-DD>
time: <local time as given>
meeting_type: <client_working_session | planning | group_call | personal_catchup | demo_walkthrough | internal | other>
counterpart: <name from title, or "unknown">
counterpart_inferred: <true|false>
people_mentioned: [<names literally spoken in the transcript>]
tools_products: [<tools/products/companies discussed>]
source: granola
meeting_id: <uuid>
generated: <YYYY-MM-DD>
tags: [<3-8 lowercase topical tags>]
---
```

Body sections, in order:

1. **TL;DR** - 2-4 sentences, neutral third-person, the "if you read nothing else" version.
2. **Topics Discussed** - the verbose core. One subsection per real topic, ordered by importance (not by when it came up). Capture the WHY: reasoning, alternatives weighed, nuance the summary flattened.
3. **Decisions Made** - things actually agreed (not floated). Add a short "- because ..." where useful. If left open, it belongs in Open Questions.
4. **Action Items** - a table: Owner | Action | Timing. Owner is the note owner or a named third party where clear; otherwise `?`.
5. **Key Moments & Notable Quotes** - pivotal exchanges and memorable framing. Quotes VERBATIM (lightly cleaned for filler only), attributed by content. Ordered by sequence.
6. **Open Questions / Unresolved** - loose threads, parked items, blockers.
7. **People & Entities** - scoped to what is derivable (NOT a verified roster): Counterpart (from title); Others mentioned (names literally spoken, role only when context makes it obvious, else flag); Tools/products/companies.
8. **Glossary / Term Corrections** - OPTIONAL per-note list of the speech-to-text fixes applied. Can be omitted from the human-facing doc; the master glossary still records them.

---

## 6. Voice and style

- Neutral third-person ("{{OPERATOR_FIRST_NAME}} walked the client through the migration," not "I walked...").
- Verbose but not padded - every sentence carries information.
- No cheesy or editorializing phrasing ("they bonded," "warm rapport," framing a quip as a profound closing). State what happened plainly.
- Do not over-hedge in the body. Keep uncertainty in glossary flags, not meta-notes like "flag anything that reads wrong."
- No em dashes or en dashes. Use a single hyphen "-". Ranges: "July-August", "$10-15k".
- No emojis.

---

## 7. Accuracy and attribution protocol

This feeds a knowledge base, so nothing false is stated as fact.

- State only what the transcript or summary supports; do not invent detail.
- Names: `Me` -> owner. Counterpart -> from the title. Third-party names -> only as literally spoken; flag roles you cannot confirm.
- Numbers/dates/dollars: include only if stated; if garbled, write the best reading + `[unverified]`.
- Claims made IN the meeting are reported as what the speaker SAID, attributed to them, not asserted as fact.
- Separate Decisions (agreed) from Open Questions (floated). When in doubt, it is an open question.
- Prefer a flagged gap over a confident guess.

---

## 8. Glossary normalization (how)

Keep a master glossary in this file (seed below - it accretes with every run). Mechanics:

- Columns: "Possibly heard as" -> "Correct term" -> Notes. The left column lists representative mishears, NOT exact strings; also fix close phonetic/spelling variants of the same term.
- Mark uncertainty with `[best guess]` or `[unverified]`; never "correct" a term into something the audio does not support.
- Each run: normalize any listed term, add new mistranscriptions you resolve, and optionally list the applied fixes in the note's own Glossary section.
- Terms still flagged `[best guess]`/`[unverified]` after authoring get surfaced to {{OPERATOR_FIRST_NAME}} in Slack after filing (SKILL.md, "Glossary escalation"); confirmations are applied via an idempotent re-file AND added to the master glossary below - each term is asked at most once, ever.
- Counterpart names never need glossary entries (they come from the title). The People part of the glossary is for third parties only.

---

## 9. Large transcripts

If `get_meeting_transcript` is too large to read in context, do not guess from the summary alone. Spawn a subagent that reads the full transcript (slicing by character range if needed) and returns ONLY: (1) nuance/reasoning beyond the summary, per topic; (2) 10-14 verbatim quotes tagged by speaker; (3) decisions vs. open questions and action items with owners/timing; (4) speech-to-text mishears; (5) confirmation it read the whole thing. Then author from the summary plus that material.

---

## 10. Definition of done

- Counterpart correct (from title); attribution sane (especially in-person).
- Sections present and ordered; Decisions vs. Open Questions separated.
- Quotes verbatim; numbers attributed to the speaker, flagged if garbled.
- Glossary normalization applied; uncertain terms flagged.
- No em/en dashes; no cheese; no over-hedging.
- Two paired files written with the same `YYYY-MM-DD - <title>` base name; the HTML handed to the brief manifest.

---

## Master glossary (seed - accretes with every run)

Representative mishears -> correct term. The left column is not exhaustive; also fix close variants. Flags: `[best guess]` = likely but unconfirmed; `[unverified]` = could not confirm. When unsure, keep the flag rather than asserting.

Seed it with a few common AI-tool mishears; the real value builds as runs add {{OPERATOR_FIRST_NAME}}'s customers, products, and jargon.

### AI tools, models & frameworks

| Possibly heard as | Correct term | Notes |
|----------|--------------|-------|
| cloud code, clog code, club code | Claude Code | Anthropic's CLI coding tool |
| any then, "and then" (as a tool) | n8n | workflow automation |
| 11 laps, 11 labs, eleven labs | ElevenLabs | voice / audio generation |

### People (third parties only)

| Possibly heard as | Correct term | Notes |
|----------|--------------|-------|
| *(accretes per run)* | | |

### Companies, products & projects

| Possibly heard as | Correct term | Notes |
|----------|--------------|-------|
| *(accretes per run - the operator's customers and products land here)* | | |
