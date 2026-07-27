# Slack & the Gateway

> Slack is the daily driver — the only interactive surface the operator uses remotely. The gateway is the always-on process behind it. Decision baked into this design: **Slack only** — no second chat platform, no web UI off-box, no tunnel.

## The Slack app (Phase 5)

- Create the app **from the shipped manifest template** (`templates/slack-manifest.agentview.json.template` — substitute `{{AGENT_NAME}}`, paste at api.slack.com/apps → "Create New App" → "From a manifest"). It sets scopes, events, Socket Mode, the Messages-tab agent view (platform ≥v0.19; a one-way migration Slack requires eventually), and a **curated 37-command slash registry** in one shot. Do NOT use raw `hermes slack manifest --agent-view` output for the app: it ships exactly 50 built-in commands (Slack's per-app cap — zero room for customs) **including `/update`, which runs an unpinned platform update from any phone keyboard** — the exact thing the pinned-version ceremony exists to prevent. The template is the raw 50 minus 16 pruned (`/update`, `/yolo`, `/kanban`, `/curator`, `/blueprint`, `/suggestions`, `/bundles`, `/learn`, `/title`, `/branch`, `/rollback`, `/subgoal`, `/codex-runtime`, `/footer`, `/personality`, `/platform`) plus the 3 ops customs (`/jobs`, `/backup-status`, `/reminders` — their shell commands are wired in Phase 7's `quick_commands`). Pruned commands still work via the `!` prefix — removal only affects `/` autocomplete (and for `/update`, that's the point: updates go through the ceremony, not chat). On future platform version jumps, rebuild rather than regenerate: generate the new raw manifest, re-apply the same cut list + customs, diff against the previous file (a raw paste resurrects all 50 and drops the customs). Since platform v0.19 the gateway renders tool-progress bubbles into chat (`display.tool_progress: all` is the global default) — if you prefer clean final-answers-only in Slack, set `display.platforms.slack.tool_progress: 'off'` (quoted — bare `off` becomes a YAML boolean). If you add custom quick-command entries to the manifest, **omit `usage_hint` rather than setting it to `""`** (Slack rejects empty strings), and expect a **reinstall prompt** whenever scopes change — the reinstall is what makes them take effect.
- **Socket Mode** = an *outbound* websocket from the box to Slack. No inbound listener, no public URL — the load-bearing fact of the remote-access posture.
- `.env`: `SLACK_BOT_TOKEN` (xoxb-), `SLACK_APP_TOKEN` (xapp-, `connections:write`), **`SLACK_ALLOWED_USERS`** (the operator's member ID — **set before the first message**), `SLACK_HOME_CHANNEL`.
- Inline replies (`platforms.slack.extra.reply_in_thread: false`) keep channels conversational.

## Channels = personas

Three free-response channels (no @mention needed), persona text instantiated from [templates/identity/personas.md.template](../templates/identity/personas.md.template) into **`slack.channel_prompts` — the single canonical home.** Never duplicate persona text into `agent.personalities`: two homes drift (the reference build's duplicate was missing a critical scoping rule the live one had — that's how it was caught).

| Channel | Persona |
|---|---|
| `#general` | Chief of staff — SOUL itself, no extra prompt |
| `#research` | Gather → synthesize → present-then-file; KB-first; explicit scope on every store |
| `#proposals-contracts` | Consultative playbook drafter + contract mode (skeleton-driven services agreements); pulls KB + operator-email context; discovers before drafting; **drafts, never sends** (sending happens only via the gated e-sign skill) |

All three are **free-response channels** (`slack.free_response_channels` = their IDs): the agent replies to every message without needing an @-mention. The platform default is mention-gated — an install that skips this key looks alive but only answers when summoned.

**Plus one broadcast-only ops channel — `#system-messages`** (ID pinned as `SYSTEM_NOTIFY_CHANNEL` in `.env`; deliberately NOT free-response — nothing listens there). Fed by `scripts/system_notify.sh` (`hermes send` — zero-token, bot-token direct, works with the gateway down): gateway-startup notices (the `hooks/system-notify` gateway hook — fires on manual restarts, updates, AND crash-recoveries, so a crash loop is visible as a burst), same-moment failure pings from the nightly jobs (backup, docs push, docs-sync, marker-wrapped crons), and the digest's daily one-line headline. The platform's own "♻ Gateway restarted/shutting down" session notices are OFF (`slack.gateway_restart_notification: false`) — the hook's line replaces them; if the hook is ever removed, restarts go silent rather than falling back to a persona channel.

## Media in — and what does NOT happen

- **Voice notes** auto-transcribe at the gateway (local `faster-whisper`, on-box, free) and inject as text. Model: `small` (`stt.local.model` — deliberately above the `base` default for accuracy).
- **File uploads** (PDF/DOCX/CSV/images) are read into the conversation as *context*. They are **never auto-filed to the KB** — filing is the `file-to-kb` skill, behind the offer-then-file gate.

## The gateway process

- The one always-on service (KeepAlive). Manage with `hermes gateway start|stop|restart|status`.
- **Any config.yaml or SOUL.md change → restart.** The Slack "Gateway shutting down" message is a restart, not a crash — it drains in-flight runs and self-heals in seconds.
- **SOUL is snapshotted per session:** live conversations keep the old SOUL; the **daily 4am session reset** means changes always land by morning, and `/new` forces it now.
- Logs live in `~/.hermes/logs/`; the ops digest checks the process daily (a dead gateway is a red row, not a silent absence).

## Boundaries recap

Allowlisted to one member ID · outbound socket only · dashboard on localhost · full history searchable later (`state.db`) — the convenience surface never weakens the no-ingress posture.
