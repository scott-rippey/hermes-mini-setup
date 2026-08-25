# Morning Brief & Ops Digest

> Two morning emails with opposite personalities, by design: the **brief** (8:00) is *synthesized* — what today means; the **digest** (8:10) is *deterministic* — what the machine did. Both sent from the agent account to the operator (auto-allowed self-reporting).

> **Model names in emailed output are dynamic:** footers and the digest's labeled synthesis card render `_agent_model_name()` — a per-script helper that reads `model.default` from config.yaml at send time. Never hard-code a model name into user-facing output; a model switch must not require a script scrub.

## Morning brief — 8:00 (`templates/scripts/morning_brief.py.template`)

1. **Deterministic gather:** today's calendar (the operator's shared calendar), recent unread, open tasks — via the Google CLI.
2. **Synthesis** via a headless agent run: what today is *about*, the priorities, the threads. Output extracted between HTML markers, fence-stripped, sanity-guarded, with a deterministic fallback so the email always arrives.
3. **Polished HTML email** — synthesis leads; raw facts demoted to a compact "details" block. Mobile-first (no wide tables — card-style sections). No PDF, ever.
4. **Meeting reports inline:** anything the previous night's meeting pipeline queued renders inside the brief.

**Audio brief (standard — free, fully local):** the 8am email carries an **m4a audio version** narrated by Kokoro local TTS (`mlx-community/Kokoro-82M-bf16`, dedicated venv `~/.hermes/kokoro-venv` — same isolation pattern as scrapling; 54 voices, pick one in `KOKORO_VOICE`). The same synthesis call emits a second `<!--AUDIO-->` fragment: a spoken script that is a **lighter cut** — the day's shape, calendar with times as words, key tasks (work first, trivial errands get a few words), email in passing, meeting reports compressed to who/when/takeaway. Rendered `mlx_audio.tts.generate --join_audio` → `afconvert` → m4a → attached. **Soft dependency:** no venv or any TTS failure → the brief ships without audio (`audio=skipped`), never fails. Fully local — brief content (calendar/email) never leaves the box for TTS; that's why cloud TTS was rejected.

## Ops digest — 8:10 (`templates/scripts/ops_digest.py.template`)

Deterministic (no LLM) except ONE clearly-labeled section. Subject flips to ⚠️ on any failure. Its stance: **silence is never success** — every subsystem has a row, including "supposed-to-exist-and-doesn't" states like an unpushed docs repo.

| Section | What it checks |
|---|---|
| Cron health | The **gateway process** + every job from its log: backup, meeting pipeline, docs-sync, brief, **the 15-min prep poller (staleness >35m = FAIL)**, per-call report outcomes, **the 15-min e-signature poller (optional; staleness + end-of-run marker; row gated on the skill dir)**, and yesterday's own digest |
| **Platform cron (reminders)** | State-based watch on `~/.hermes/cron/jobs.json` (the agent-created reminder store — see [architecture.md](architecture.md)): empty or pending one-shots (named) ⇒ OK; **any RECURRING job ⇒ FAIL** (the one-shot-only rule was bypassed); a reminder in error state ⇒ FAIL. Self-activating — no artifact gate (an absent file = OK/empty) |
| **Docs repo push** | State-based: no upstream / unpushed commits / uncommitted files ⇒ FAIL |
| Agent activity | Sessions, tool calls, tokens (the real signal on a flat-rate plan; est-cost is a footnote) |
| Knowledge base | Filed docs vs GitHub-synced docs (each +24h/total — the docs-sync inflates a single "documents" number), chunks as embedded total, meetings +24h/total |
| Backup | Last bundle name/size/age |
| **System changes** | The 3:05 ledger snapshot's diffstat + the **AI narrative** — the one synthesized section, hard-grounded (statements must be diff-evidenced; unsure ⇒ omit) with the raw diffstat always rendered beneath as checkable truth |
| **Memory stores** | A daily mirror of the memory tool's drift check (format round-trip + budgets + refused-write detection) — run from *outside* the agent |
| **Memory content audit** | Only rendered when the weekly (Monday) audit has findings or errored: contradictions between memory entries, entries restating a SOUL rule, time-expired entries, near-budget stores (≥85%). Reads the `memory-audit.{html,meta.json}` artifact (≤8 days fresh) written by the change-narrative feeder — see [memory-system.md](memory-system.md) |
| **Staged writes awaiting approval** | Only rendered when `~/.hermes/pending/*/` is non-empty: each staged item's subsystem, summary, origin, age. Informational — the q5m `pending-watch` job already pinged the ops channel when each landed |
| Voice balance | Prepaid phone credit (if the module's on), warn thresholds |

After the email sends, a **one-line headline posts to Slack `#system-messages`** ("✅ all systems green" / "⚠️ N failing — named rows"), and a send-failure of the digest email itself posts a 🔴 line — otherwise that failure is invisible until the *next* digest grades it. Full report stays in email; the channel is scannable history ([slack-gateway.md](slack-gateway.md) has the channel's full feed list). Dry-run skips the headline too.

## The change-narrative feeder — 3:05 (`templates/scripts/system_changes.py.template`)

Commits the day's `~/.hermes` changes to the local ledger → diffs the last 24h (plus the docs repo's delta) → a short AI narrative under the grounding contract → artifacts the digest embeds. Runs before the 3:10 push and 3:15 bundle so all three nightly captures agree.

**Mondays it also runs the built-in-memory content audit** (`memory_audit()` — deterministic near-budget check + one flag-only AI pass of USER.md/MEMORY.md against SOUL; writes `logs/memory-audit.{html,meta.json}` for the digest's findings-only section; `FORCE_MEMORY_AUDIT=1` forces a run any day). Wrapped so an audit failure never blocks the ledger snapshot — it reports itself in the meta and surfaces as a FAIL line in the digest section instead.

## Why this split works

The brief answers "what should I do today?" — judgment welcome. The digest answers "did the machinery work?" — judgment is contamination there, except the one labeled narrative whose every claim is checkable against the diffstat printed under it. Grounded-or-absent is the rule.
