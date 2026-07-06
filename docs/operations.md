# Operations Runbook

> The "how to run the box" doc — hand this to the operator at sign-off (Phase 11). Daily rhythm, procedures, the update ceremony, troubleshooting. When something here changes, change this doc in the same session.

## Daily rhythm (what healthy looks like)

| When | Arrives / happens | Green looks like |
|---|---|---|
| 3:05a | Ledger snapshot + change narrative | a line in `system-changes.log` |
| 3:10a | Docs push | `pushed OK` / `clean + in sync` |
| 3:15a | Encrypted bundle → Drive | `=== backup … OK ===` |
| 4:00a | Sessions reset (automatic `/new`) | invisible; morning chats start fresh |
| 8:00a | **Morning brief** | synthesis + details + meeting reports |
| 8:10a | **Ops digest** | 🔧 subject, all rows OK — ⚠️ = read now |
| 9:00p / 10:00p | docs-sync / meeting reports (if enabled) | per-job log lines |
| every 15m | Prep poller | quiet one-liners; prep ~2h before addressed meetings |

**The digest is the single pane.** A ⚠️ subject is your morning to-do; a *missing* digest email is itself the alarm.

## Job control

User LaunchAgents in `~/Library/LaunchAgents/ai.hermes.*.plist`, logs in `~/.hermes/logs/`. Gateway: `hermes gateway start|stop|restart|status`. Crons: `launchctl bootstrap|bootout gui/$(id -u) <plist>`.

## Standard procedures

- **Config change:** edit → YAML-validate → gateway restart → the ledger records it tonight (or commit deliberately with a message).
- **SOUL/persona change:** edit → restart → lands in NEW sessions (4am guarantees by-morning; `/new` for now).
- **New scheduled capability — skill before cron:** build → smoke-test standalone → wire → verify end-to-end → only then schedule (instantiate `templates/launchd/`; don't collide with the 3:05/3:10/3:15 trilogy or 8:00/8:10).
- **Snapshot before destroying anything**; the ledger records every `~/.hermes` change regardless.
- **What changed lately?** `git -C ~/.hermes log --stat`, or yesterday's digest.

## The platform-update ceremony (version stays PINNED; updates are deliberate)

Pre: `updates.pre_update_backup: true` (set it in Phase 2 and never unset) · commit the ledger · `hermes skills list-modified`.

Update, then re-apply:
1. **google-workspace modified scripts** ← [templates/google-workspace/](../templates/google-workspace/)
2. **Skills reseed check:** newly bundled skills arrive ENABLED → add to `skills.disabled`
3. **Optional core hardening**, if you adopted it (both are small, platform-core edits — re-do after updates):
   - *Skill-patch guard:* make the skill self-edit tool refuse fuzzy `block_anchor`/`context_aware` match strategies (in the platform's fuzzy-match/skill-manager tools) — prevents a background improvement loop from corrupting SKILL.md files via loose matches. The reference build adopted this after exactly that corruption.
   - *Notice gate:* suppress a per-session model-compaction notice in chat if it bugs you (cosmetic).
4. Telephony copy: untouched by updates (re-apply [telephony-mods](../templates/telephony-mods/PATCHES.md) only after a skill *reinstall*).
5. Gateway restart → next morning's digest confirms the board.

## Troubleshooting quick-refs

| Symptom | Cause / fix |
|---|---|
| Digest "Memory stores" row red | Drift or a refused write — [memory-system.md](memory-system.md); never hand-fix by editing USER.md into doc form |
| Phone API 403 / error 1010 | Cloudflare vs. the default Python UA — the UA patch is missing (reinstalled skill?) |
| `security add-generic-password` says "already exists" | A **blank** entry from a non-interactive attempt — delete it, re-run in a real Terminal |
| Claude Code can't read Downloads/Desktop/Documents | macOS TCC — move the file to `~` or the repo |
| Call rings straight to voicemail | Recipient's unknown-caller silencing — save the number to Contacts |
| Travel card says OpenStreetMap instead of Google | The fallback did its job — check `google route unavailable` in the prep log + the Routes key |
| No travel block at all | By design when the invite lacks a physical address |
| "Gateway shutting down" in Slack | A restart, not a crash — self-heals in seconds |
| Config edit didn't change behavior | Forgot the restart, or the session predates it (4am fixes) |
| MCP OAuth won't complete headless | The pty + timeout dance — [meeting-pipeline.md](meeting-pipeline.md) |

## Cadence

Day one: manual backup + **full scratch-restore drill** + passphrase off-box · quarterly: decrypt spot-check · semi-annual: restore drill · after every update: the ceremony above.
