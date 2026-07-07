# Morning Brief & Ops Digest

> Two morning emails with opposite personalities, by design: the **brief** (8:00) is *synthesized* — what today means; the **digest** (8:10) is *deterministic* — what the machine did. Both sent from the agent account to the operator (auto-allowed self-reporting).

## Morning brief — 8:00 (`templates/scripts/morning_brief.py.template`)

1. **Deterministic gather:** today's calendar (the operator's shared calendar), recent unread, open tasks — via the Google CLI.
2. **Synthesis** via a headless agent run: what today is *about*, the priorities, the threads. Output extracted between HTML markers, fence-stripped, sanity-guarded, with a deterministic fallback so the email always arrives.
3. **Polished HTML email** — synthesis leads; raw facts demoted to a compact "details" block. Mobile-first (no wide tables — card-style sections). No PDF, ever.
4. **Meeting reports inline:** anything the previous night's meeting pipeline queued renders inside the brief.

## Ops digest — 8:10 (`templates/scripts/ops_digest.py.template`)

Deterministic (no LLM) except ONE clearly-labeled section. Subject flips to ⚠️ on any failure. Its stance: **silence is never success** — every subsystem has a row, including "supposed-to-exist-and-doesn't" states like an unpushed docs repo.

| Section | What it checks |
|---|---|
| Cron health | The **gateway process** + every job from its log: backup, meeting pipeline, docs-sync, brief, **the 15-min prep poller (staleness >35m = FAIL)**, per-call report outcomes, and yesterday's own digest |
| **Docs repo push** | State-based: no upstream / unpushed commits / uncommitted files ⇒ FAIL |
| Agent activity | Sessions, tool calls, tokens (the real signal on a flat-rate plan; est-cost is a footnote) |
| Knowledge base | Filed docs vs GitHub-synced docs (each +24h/total — the docs-sync inflates a single "documents" number), chunks as embedded total, meetings +24h/total |
| Backup | Last bundle name/size/age |
| **System changes** | The 3:05 ledger snapshot's diffstat + the **AI narrative** — the one synthesized section, hard-grounded (statements must be diff-evidenced; unsure ⇒ omit) with the raw diffstat always rendered beneath as checkable truth |
| **Memory stores** | A daily mirror of the memory tool's drift check (format round-trip + budgets + refused-write detection) — run from *outside* the agent |
| Voice balance | Prepaid phone credit (if the module's on), warn thresholds |

## The change-narrative feeder — 3:05 (`templates/scripts/system_changes.py.template`)

Commits the day's `~/.hermes` changes to the local ledger → diffs the last 24h (plus the docs repo's delta) → a short AI narrative under the grounding contract → artifacts the digest embeds. Runs before the 3:10 push and 3:15 bundle so all three nightly captures agree.

## Why this split works

The brief answers "what should I do today?" — judgment welcome. The digest answers "did the machinery work?" — judgment is contamination there, except the one labeled narrative whose every claim is checkable against the diffstat printed under it. Grounded-or-absent is the rule.
