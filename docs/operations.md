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

**Zero-token ops slash commands from Slack** (`quick_commands` in config.yaml — shell exec, no LLM, 30s timeout; invoke with the `!` prefix — `!jobs` etc. — because Slack intercepts unregistered `/` commands client-side; registering them natively on the Slack app is optional cosmetics, and `!` also works inside threads): the reference build ships `/jobs` (launchd jobs + last exit codes), `/backup-status` (backup log tail + newest bundles), `/reminders` (pending one-shots via `templates/scripts/list_reminders.py.template`, flags rule-violating recurring jobs). Use absolute paths in the commands; quick commands are checked before skill commands, so don't name one after a skill.

## Standard procedures

- **Config change:** edit → YAML-validate → gateway restart → the ledger records it tonight (or commit deliberately with a message).
- **SOUL/persona change:** edit → restart → lands in NEW sessions (4am guarantees by-morning; `/new` for now).
- **New scheduled capability — skill before cron:** build → smoke-test standalone → wire → verify end-to-end → only then schedule (instantiate `templates/launchd/`; don't collide with the 3:05/3:10/3:15 trilogy or 8:00/8:10).
- **Snapshot before destroying anything**; the ledger records every `~/.hermes` change regardless.
- **What changed lately?** `git -C ~/.hermes log --stat`, or yesterday's digest.

## The platform-update ceremony (version stays PINNED; updates are deliberate)

Pre: `updates.pre_update_backup: true` (set it in Phase 2 and never unset) · commit the ledger · `hermes skills list-modified`.

**Version-jump review BEFORE running the update** — read every release note between the pinned and target versions for **default-behavior flips**. Known ones on the v0.17→v0.19 path (the reference build ran this jump live): **v0.19 made LLM-judged "smart approvals" the platform default** — an explicit `approvals.mode: manual` in config.yaml overrides it, but re-verify (plus `approvals.cron_mode: deny`) after every update before the gateway goes back up. v0.19 also ships **new skills enabled** (`docx`/`pdf`/`xlsx` — the reference build adopted all three deliberately) and **new toolsets inside bundles** (`project`, `video`, `video_gen`); v0.18 adds `/goal`, `/learn`, `/journey` — check `/learn`-created skills against default-deny. The durable gateway delivery ledger (at-least-once Slack delivery) is a reason TO take the update. **Two mechanics from the live run:** the update **auto-restarts the gateway when it finishes** — patches and config checks land after that restart, so finish the whole list and restart again; and `hermes doctor` may flag an outdated `_config_version` — run `hermes doctor --fix`, then audit its rewrite **semantically** (parse pre/post YAML and diff values; the rewriter also re-wraps long strings, which is noise — renames and default flips are the signal).

Update, then re-apply:
1. **google-workspace modified scripts** ← [templates/google-workspace/](../templates/google-workspace/)
2. **Skills reseed check:** newly bundled skills arrive ENABLED → add to `skills.disabled`; `agent.disabled_toolsets` survives (config), but re-scan the toolset registry for never-discussed new tools
3. **Optional core hardening**, if you adopted it (both are small, platform-core edits — re-do after updates):
   - *Skill-patch guard:* make the skill self-edit tool refuse fuzzy `block_anchor`/`context_aware` match strategies (in the platform's fuzzy-match/skill-manager tools) — prevents a background improvement loop from corrupting SKILL.md files via loose matches. The reference build adopted this after exactly that corruption. (The primary gate is `skills.write_approval: true` — config, survives updates, nothing to re-apply; this patch is the mechanical layer beneath it.)
   - *Notice gate:* suppress a per-session model-compaction notice in chat if it bugs you (cosmetic).
   - *Quick-command slash listener:* only if you natively registered custom quick commands on the Slack app — the platform's bolt listener patterns only built-in command names, so registered customs (e.g. `/jobs`) get "app did not respond" until you extend the pattern with the config's `quick_commands` keys (a few lines where `_slash_names` is built in the Slack adapter). The `!jobs` prefix form works without any patch.
4. Telephony copy: untouched by updates (re-apply [telephony-mods](../templates/telephony-mods/PATCHES.md) only after a skill *reinstall*).
5. **Slack manifest refresh** (on updates that change the generated manifest — v0.19 adds `--agent-view`): rebuild from the shipped template's curation, never paste a raw regen — regenerate, re-apply the cut list + customs from [slack-gateway.md](slack-gateway.md) (16 pruned incl. `/update`; Slack caps an app at 50; a raw regen restores every built-in — `/update` included — and drops customs), and update `templates/slack-manifest.agentview.json.template` to match. Custom entries must **omit `usage_hint` entirely rather than set it to `""`** — Slack's validator rejects empty strings. If the new manifest adds scopes (agent-view adds the group-DM set), Slack requires an app **reinstall** after saving — the gateway log's scope warning disappearing confirms it took.
6. Gateway restart (if `hermes gateway status` reports the launchd service definition stale, run `hermes gateway start` to rewrite it) → a live `/`-command and a `hermes -z` probe → next morning's digest confirms the board.

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
| Fallback 400 "third-party apps now draw from your extra usage" despite a funded key | Claude Code's OAuth login outranks `ANTHROPIC_API_KEY` in the credential ladder — put the same console key in `ANTHROPIC_TOKEN` too ([architecture.md](architecture.md) Models); re-run the force-test |
| "Gateway shutting down" in Slack | A restart, not a crash — self-heals in seconds |
| Config edit didn't change behavior | Forgot the restart, or the session predates it (4am fixes) |
| MCP OAuth won't complete headless | The pty + timeout dance — [meeting-pipeline.md](meeting-pipeline.md) |

## Cadence

Day one: manual backup + **full scratch-restore drill** + passphrase off-box · quarterly: decrypt spot-check · semi-annual: restore drill · after every update: the ceremony above.
