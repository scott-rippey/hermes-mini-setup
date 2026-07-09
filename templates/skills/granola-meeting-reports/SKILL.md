---
name: granola-meeting-reports
description: Turn a Granola meeting into a structured Markdown record filed in the KB (under the right customer/person, in the meetings table) plus an email-safe HTML report that rides the morning brief. Use when {{OPERATOR_FIRST_NAME}} says "process my latest Granola meeting", "redo the meeting report for X", or when run headlessly by the ai.hermes.meeting-reports cron.
version: 1.0.0
author: hermes-mini-setup (reference build)
license: MIT
platforms: [macos]
prerequisites:
  commands: [node]
  mcp: [granola, rag]
metadata:
  hermes:
    tags: [Granola, Meetings, Reports, Knowledge Base, KB, Productivity]
---

# Granola Meeting Reports

Turn a Granola meeting into two artifacts and route them:
1. a structured **Markdown** record + a row in the **`meetings`** table, filed in the KB under the right **customer** (and **person**), searchable;
2. an email-safe **HTML report** that gets delivered inline in {{OPERATOR_FIRST_NAME}}'s **8am morning brief** (no PDF, no attachment).

Trigger when {{OPERATOR_FIRST_NAME}} says "process my latest Granola meeting", "redo the meeting report for X", or when the `ai.hermes.meeting-reports` cron runs this headlessly (nightly 10pm).

**Authoring spec = the bundled `AUTHORING.md`** — the single source of truth for the content template, voice, accuracy protocol, and glossary mechanics. Follow it for CONTENT; rendering is `render.js` → Markdown + HTML.

## Tools and helpers
- **Granola:** `mcp_granola_list_meetings`, `mcp_granola_get_meetings` (AI summary), `mcp_granola_get_meeting_transcript` (full transcript).
- **Render:** `node <skill>/render.js <content.json>` writes `markdown/<base>.md` (KB copy) + `html/<base>.html` (brief fragment) from ONE content object. See `samples/sample-meeting.json` for the exact content schema.
- **KB filing:** `mcp_rag add_meeting` (stores the markdown doc + upserts the `meetings` row).
- **Delivery:** append each report to `<skill>/state/pending-brief.json` (see Hand-off); the 8am brief embeds the HTML inline and clears it. The nightly run does NOT email.
- **Slack escalation:** `hermes send -t slack:#general "<message>"`.
- **Output folder:** `~/{{AGENT_SLUG}}-outputs/granola-reports/{markdown,html}/`.

## Run loop (per meeting)
1. **Select.** Default to the most recent unprocessed meeting via `mcp_granola_list_meetings` (the cron passes a since-window). **SKIP** any title containing "livestream". Skip meeting IDs already in `state/processed.json`.
2. **Pull both** `get_meetings` (summary) and `get_meeting_transcript` (full). If the transcript is too large for context, offload to a subagent per AUTHORING.md ("Large transcripts").
3. **Author** the report as a **content JSON** (the structure in `samples/sample-meeting.json`) per AUTHORING.md (template, voice, accuracy, glossary). Counterpart = the `w/ <Name>` in the title. Base name = `YYYY-MM-DD - <sanitized title>` (`w/` -> `w`).
4. **Render.** `node render.js <content.json>` -> `markdown/<base>.md` + `html/<base>.html`.
5. **Hand off for delivery — ALWAYS** (regardless of filing outcome): append the report to `state/pending-brief.json` with its **HTML** so the 8am brief delivers it inline (see Hand-off).
6. **Resolve + file** via `add_meeting` (below). Record the meeting ID in `state/processed.json`.
7. **Glossary escalation — part of every run, never skip:** after all meetings are filed, if ANY authored report carries `[best guess]` / `[unverified]`, post the one-message escalation to Slack #general (section below). If you delegated authoring or filing to a subagent, this step still belongs to YOU — the outer run owns steps 5-7.

## Filing — resolution and the two cases
File with `mcp_rag add_meeting` — stores the searchable markdown AND upserts the `meetings` row (linked to customer, person, and the KB doc). Use `add_meeting`, NOT `store`:
- `content` = the Markdown (from `markdown/<base>.md`)
- `title` = `<YYYY-MM-DD> - <Granola title>` (re-filing the same `meeting_id` updates the row + doc)
- `counterpart` = the person from the "w/ Name" title
- `customer` = optional — `add_meeting` auto-files a multi-company counterpart under their **primary** company; pass only to override
- `meeting_id` = the Granola meeting id (dedupe key); `meeting_date` = `YYYY-MM-DD`; `meeting_type` = a value from the template

Resolve the counterpart against people cards (the resolver matches name / alias / email, companies primary-first):
- **Name matches -> one company:** `add_meeting` with `counterpart` only. Silent.
- **Name matches -> multiple companies** (a person linked to several companies): `add_meeting` with just `counterpart` — auto-files under the **primary** company (shown as "Filed under" in the report so a rare miss is catchable). Silent.
- **No match** (new/unknown name), or **no `w/ Name`**: do NOT file. **Escalate to Slack** (below); leave pending until {{OPERATOR_FIRST_NAME}} assigns.

## Escalation (Slack #general)
When the counterpart can't be resolved, post with `hermes send -t slack:#general "<message>"`:
> New meeting "<title>" (<date>): I couldn't match "<name>" to a person card. Onboard them (customer-onboarding / contact-onboarding) or tell me which customer to file it under. The report will be in your morning brief.

Then stop for that meeting (its HTML still goes to the manifest in step 5, so it appears in the next brief marked unassigned). When {{OPERATOR_FIRST_NAME}} replies, file it with the person/customer he names.

## Glossary escalation (same channel — ask once, learn forever)
After the run has filed (or escalated) its meetings, collect every flagged term across the reports just authored (`[best guess]` / `[unverified]`). If there are any, post ONE message for the whole run to Slack #general:

> Meeting report "<title>" (<date>) filed with <N> flagged term(s): "<as heard>" -> "<best guess>" [best guess]; "<context of the garbled bit>" [unverified]. Reply with corrections (or "all correct") and I'll re-file and remember them.

Never block or delay filing on an unanswered glossary question — flags stay in the filed report until answered. When {{OPERATOR_FIRST_NAME}} replies (typically the next morning, in a fresh session — the Slack thread carries all needed context):
1. Apply the corrections to the content JSON, re-render, re-file via `add_meeting` (same `meeting_id` — idempotent upsert; the corrected report replaces the KB doc).
2. Add each confirmed term to the master glossary (AUTHORING.md, "Master glossary" table) so it is never asked again. "All correct" confirmations go in too — a confirmed `[best guess]` becomes a plain glossary row.
3. Do NOT re-append to `state/pending-brief.json` (the original already rode a brief); confirm the correction in the chat thread instead.

## Hand-off to the morning brief
After rendering, append one entry per report to `state/pending-brief.json` (a JSON array; create as `[]` if missing). Put the **contents of `html/<base>.html`** in the `html` field:

    { "title": "<Granola title>", "date": "<YYYY-MM-DD>", "company": "<filed company, or 'Unassigned (see Slack)'>", "html": "<the HTML fragment from html/<base>.html>" }

The 8am morning brief embeds each `html` fragment inline under "Meeting reports", then clears the file (writes `[]`). Append (never overwrite) so several meetings in one run all ride the next brief.

## Sanctioned auto-write
This pipeline's KB filing is a **sanctioned automatic write** — same category as the github-docs-sync cron, NOT the interactive present-then-file gate. It auto-files on a confident resolution (the mapping is deterministic) and **escalates to {{OPERATOR_FIRST_NAME}} instead of guessing** when resolution is ambiguous or missing. Do not ask permission per meeting; do escalate per the rule above.

## Dedupe / state
Processed meeting IDs are recorded in `state/processed.json`. Skip any ID already listed; append an ID once its report has been handed to the manifest (step 5) so an escalated-but-unfiled meeting is never re-processed.

## Notes / pitfalls
- **No PDF.** Delivery is the inline HTML report in the 8am brief; the full Markdown is in the KB (searchable). The `meetings.pdf_path` column exists but is unused.
- Idempotent: same `meeting_id` re-files/re-renders, so re-running a meeting is safe.
- Large transcripts (100K+ chars): mine via a subagent (AUTHORING.md, "Large transcripts"), then author from the summary plus that material.
- A different meeting-notes provider with an MCP server can replace Granola: keep the run loop, swap the three tool calls and the `meeting_id` source.
