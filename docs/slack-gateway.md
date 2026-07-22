# Slack & the Gateway

> Slack is the daily driver — the only interactive surface the operator uses remotely. The gateway is the always-on process behind it. Decision baked into this design: **Slack only** — no second chat platform, no web UI off-box, no tunnel.

## The Slack app (Phase 5)

- Create the app **from the generated manifest** (`hermes slack manifest`) — it sets scopes, events, Socket Mode, and slash commands in one shot. Name the bot after your agent.
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
