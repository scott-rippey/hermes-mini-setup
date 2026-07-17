# Skill templates — instantiation notes

Five production skills, genericized. To install (Phase 7; `granola-meeting-reports` in Phase 8 if selected): fill `{{PLACEHOLDERS}}` in every text file (registry: `../README.md`), verify none remain (`grep -rn "{{" <skill>` must be empty), copy each folder to `~/.hermes/skills/productivity/<name>/`, confirm discovery with `hermes skills list`, restart the gateway, and smoke-test one flow per skill.

| Skill | What it does | Note |
|---|---|---|
| `customer-onboarding` | Guided interview → canonical customer + contacts-as-people in the KB | The KB's front door |
| `contact-onboarding` | Add/link people to an existing company (many-to-many, per-company role) | Never creates companies |
| `file-to-kb` | The offer-then-file gate for shared/uploaded documents | Scoping discipline lives here |
| `deliverable-export` | Markdown → branded DOCX/PDF → scratch dir → optional email/KB | `reference.docx`/`deliverable.css` ship with a neutral deep-blue/teal look — recolor to the operator's brand if desired |
| `granola-meeting-reports` | Nightly: meeting notes (via MCP) → structured KB record + `meetings` row + inline-HTML report in the next morning brief | Optional (Phase 8). Setup below — the one skill with an MCP dependency |

`email_file.py` runs on the platform venv python (Google libs) and sends **from the agent account to the operator only** — any other recipient requires explicit approval, per SOUL.

## granola-meeting-reports — extra setup (Phase 8, if selected)

1. **Wire the Granola MCP** in `config.yaml` (any meeting-notes MCP with `list_meetings` / `get_meetings` / `get_meeting_transcript` can substitute — see the note at the end of its SKILL.md):

   ```yaml
   mcp_servers:
     granola:
       url: https://mcp.granola.ai/mcp
       auth: oauth
       enabled: true
   ```

2. **OAuth needs a real TTY.** `hermes mcp login granola` opens a browser and waits for the redirect — run it in the operator's Terminal, not through the agent (the gateway is non-interactive, and the login times out fast on slow redirects; if it does, retry in Terminal). Verify with a `list_meetings` call after.
3. **No npm install** — `render.js` uses Node built-ins only. Smoke-test the renderer standalone before wiring: `node render.js samples/sample-meeting.json /tmp/render-test` → expect `markdown/` + `html/` outputs.
4. **State files:** create `state/` with `processed.json` (`{}` or `[]` per SKILL.md usage) and `pending-brief.json` (`[]`). The shipped `morning_brief.py.template` already reads `state/pending-brief.json` from this skill's install path — that's the delivery hand-off, no extra wiring.
5. **Schedule** nightly via `templates/launchd/job.plist.template` (reference: `ai.hermes.meeting-reports` @ 10pm, after the 9pm docs-sync). **Wrap the command with the marker script** so the ops digest can grade the run deterministically — this job's log is agent prose, and prose must never be graded by keyword (`ProgramArguments`: `/bin/bash`, `~/.hermes/scripts/run_with_marker.sh`, `meeting-reports`, then the hermes command): `hermes -z "<prompt>" --skills granola-meeting-reports` with this canonical prompt (don't improvise one — a prompt that drifts from SKILL.md fights the skill every night):

   > Run the granola-meeting-reports skill now (this is the scheduled nightly run). Process any new Granola meetings since the last run, following SKILL.md exactly and in full: selection and skip rules (livestreams, state/processed.json), authoring per the bundled spec, render Markdown + HTML via render.js, append each report HTML to state/pending-brief.json so the morning brief delivers it inline, file the Markdown to the KB under the resolved customer/person or escalate unmatched names to Slack #general, post the glossary escalation if any authored terms are flagged, and record processed meeting IDs. Do NOT email anything from this run.

   Gate: process one real meeting end-to-end — KB row exists, report appears in the next brief.
6. **The authoring quality lives in `AUTHORING.md`** — voice, accuracy protocol, speaker attribution, and a glossary that accretes the operator's own jargon run over run. Don't trim it; it's why the reports read well.
