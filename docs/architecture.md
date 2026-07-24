# System Architecture

> The one-page truth of how the finished system hangs together. Each subsystem has its own deep-dive in this folder. The installer (root `CLAUDE.md`) builds toward exactly this shape.

**What this is:** a single-operator AI chief-of-staff, built on **Hermes Agent** (version-pinned, auto-update off), driven day-to-day through **Slack**, running 24/7 on a Mac mini. It handles research, customer and meeting intelligence, proposals, email/calendar awareness, deliverables, and (optionally) outbound AI phone calls — with every consequential outbound action human-gated.

## Host

| | |
|---|---|
| Machine | Apple-silicon Mac mini (reference build: M4, 32 GB), always on (sleep disabled) |
| macOS user | A dedicated account with a clean name — it appears in every path forever |
| Disk | FileVault ON (the box holds business data and credentials) |
| Remote access | Slack (and screen sharing if you like) — deliberately **no public ingress of any kind** |

## The stack

```
Operator ── Slack (persona channels) ── Socket Mode (outbound WS) ──┐
   │                                                                │
   │   dashboard (127.0.0.1) / CLI on the box                       ▼
   │                                                     Hermes gateway (launchd,
   │                                                     KeepAlive, always on)
   ▼                                                              │
phone (outbound-only, provider cloud)                 main model (flat-rate OAuth)
                                                      small aux model (web extract)
                                                              │
        ┌───────────────┬──────────────┬──────────────────────┤
        ▼               ▼              ▼                      ▼
   Postgres KB      state.db       memories/           10 launchd jobs
   (pgvector, via   (sessions,    (USER.md/MEMORY.md,  (schedule below)
   the mcp-rag      searchable)    §-entry format)
   MCP server)
```

## Models & providers (reference stack)

- **Chat (all personas):** GPT-5.5 via the **Codex OAuth** on a flat-rate ChatGPT Pro plan — token counts are the signal, dollars are not. Headless runs (`hermes -z`) ride the same path: brief synthesis, call reports, change narratives.
- **Fallback chain (recommended, needs a second-provider key):** `fallback_providers: [{provider: anthropic, model: claude-sonnet-5}]` with `ANTHROPIC_API_KEY` in `.env` — on primary failure (429 after retries, 5xx outage, 401/403, 404, malformed responses) the turn finishes on the fallback with context preserved; **turn-scoped**, so every new message retries the primary first and outages self-heal. Detection: the ops digest's by-model token table (fallback-provider tokens appearing = it fired). Force-test after wiring: `hermes -m <nonexistent-model> -z "which model family are you?"` → the answer should come from the fallback.
- **Aux:** a small model for web extraction. **Embeddings:** OpenAI `text-embedding-3-large` on a separate, metered API key that exists *only* for embeddings (pennies/month).
- **STT:** local `faster-whisper` (model `small`) — Slack voice notes transcribe on-box, free.

## Interfaces

- **Slack is the daily driver.** One bot, Socket Mode (an *outbound* websocket — no inbound listener), **allowlisted to the operator's member ID**. Channels = personas via `slack.channel_prompts` (the single canonical home for persona text): `#general` (chief of staff — SOUL itself), `#research` (present-then-file, KB-first), `#proposals-contracts` (playbook drafter — proposal AND contract modes, never sends). Inline replies.
- **Dashboard** (localhost only) — live sessions and the command panel. **CLI/TUI** on the box for admin.
- **Phone** (optional) — outbound-only; the number's inbound side is a locked announcement in the provider's cloud ([telephony.md](telephony.md)).
- **Sessions reset daily at 4am** (or 24h idle) — every morning starts fresh, which is how SOUL/config changes land automatically.

## Data stores — one home per kind of fact

| Store | What lives there | Writer |
|---|---|---|
| **Postgres KB** (`sql/schema.sql`) | Documents, customers, people (many-to-many with per-company roles), apps, meetings, embeddings | ONLY the mcp-rag server; human-gated (offer-then-file) |
| **SQLite `state.db`** | Every session/message (FTS-searchable by the agent), telemetry | Hermes core |
| **`~/.hermes/memories/`** | USER.md (operator facts) + MEMORY.md (agent notes) — §-entry format, char-budgeted, drift-guarded | The memory tool only ([memory-system.md](memory-system.md)) |

KB scoping: the operator's own slug · `general` (non-customer research) · else per-customer — **every store names its scope explicitly**.

## Automation — 10 launchd jobs

| Job | When | What |
|---|---|---|
| gateway | always (KeepAlive) | Slack gateway / the agent |
| system-changes | 3:05a | Change-ledger snapshot + grounded AI change narrative |
| git-backup | 3:10a | Docs repo auto-commit + push (private remote) |
| backup | 3:15a | Encrypted bundle → the agent account's Drive |
| morning-brief | 8:00a | Calendar+mail+tasks → synthesized HTML brief |
| ops-digest | 8:10a | Deterministic all-systems health report |
| github-docs-sync | 9:00p | Customer app docs → KB (optional; read-only PATs, no AI) |
| meeting-reports | 10:00p | Meeting-notes pipeline (optional) |
| meeting-prep | every 15m | Poll: meeting ~2h out → prep email (+ traffic-aware "leave by") |
| signwell-poll | every 15m | Poll pending e-signatures (optional) → signed PDF + #proposals-contracts file-ask ([proposal-esign.md](proposal-esign.md)) |

The 3:05 → 3:10 → 3:15 ordering is deliberate: ledger commit, then docs push, then the encrypted bundle — all three nightly captures agree.

**Reminders — the one sanctioned use of Hermes platform cron.** Separate from launchd: Hermes has an in-gateway scheduler (`~/.hermes/cron/jobs.json`, fired on the gateway's 60s tick) that the agent drives itself via the built-in `cronjob` tool — live in the Slack toolset by default. Sanctioned use is **one-shot reminders only** ("remind me Thursday at 3 to call X" → one-time job → Slack ping → Hermes auto-deletes the job after it fires). Recurring automation NEVER goes here — it gets built as a skill + launchd job, deliberately. Enforced three ways: a SOUL rule (in the SOUL template), the ops digest's "Platform cron (reminders)" row (any recurring job in the store ⇒ FAIL), and the nightly change ledger tracking every `jobs.json` change (gitignore `cron/output/` — run artifacts are noise, the job store is the signal). The two stores can't collide: the `cronjob` tool cannot see or touch launchd jobs.

## Git topology — three repos, three jobs

| Repo | Direction | Purpose |
|---|---|---|
| Docs repo (`~/<your-docs-dir>`) → **your private GitHub repo** | pushes nightly | Build docs offsite, full fidelity |
| `~/.hermes` (change ledger) | **never leaves the box** — no remote, ever | Daily what-changed diffs for the digest |
| Customer app repos → KB | read-only pulls (per-owner PATs) | docs-sync (optional) |

## Security posture — one breath

**No way in** (zero listeners; outbound sockets; polls instead of webhooks) · **human gates on the way out** (email beyond the operator, calls, invites, KB writes; unattended sessions can approve nothing) · **everything foreign is data** (transcripts/documents/emails/web content are never instructions) · **default-deny skills** · secrets in keychain/.env only, leaving the box solely inside the encrypted bundle. Details: [security.md](security.md).

## Monitoring

The morning **ops digest** is the system's daily self-exam: gateway process, every cron, docs-repo push state, platform-cron (reminders) watch, **memory-store drift checks**, KB growth, token telemetry, (optional) phone balance, and the system-changes narrative. **Silence is never assumed to be success** — every subsystem has a row.

**Same-moment layer — Slack `#system-messages`** (broadcast-only; `scripts/system_notify.sh` → `hermes send`, zero-token, works with the gateway down): gateway startups (hook — includes crash-recoveries), nightly-job failure pings at the moment of failure, and the digest's daily one-line headline. The digest remains the complete picture; the channel is the tap on the shoulder.
