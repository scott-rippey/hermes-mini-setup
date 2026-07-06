# Hermes Mini Setup — an AI chief-of-staff on a Mac mini, installed by Claude Code

Build a complete, private, always-on AI assistant ("your Sidekick") on a Mac mini — driven day-to-day from Slack, grounded in your own knowledge base, with human approval gates on everything that leaves the machine.

**The twist: Claude Code is the installer.** You don't follow this guide — Claude Code does. Clone the repo, open Claude Code inside it, and say **"let's begin."** It interviews you about your business, generates your agent's personality and profile, tells you exactly when to click what in each account signup, and does all the on-box work itself. You bring the accounts and the decisions; it brings the wiring.

## What you end up with

- **Slack as the daily driver** — persona channels (chief-of-staff / research / proposals), voice notes auto-transcribed, no public endpoints anywhere (outbound Socket Mode only)
- **A private knowledge base** (Postgres + pgvector, local) — customers, contacts, apps, meetings, documents; semantic search; every write human-approved
- **Morning intelligence** — a synthesized daily brief (calendar + email + tasks) and a deterministic ops digest that watches every subsystem, including itself
- **Meeting intelligence** — meeting notes filed automatically to the KB; prep emails ~2h before meetings, with traffic-aware "leave by" guidance when the invite has an address
- **Outbound AI phone calls** (optional) — approval-gated task calls with automatic MP3 + transcript + AI-breakdown reports to your inbox
- **Self-tracking infrastructure** — nightly encrypted off-site backups, a git change-ledger of the system itself, daily AI-written (and diff-grounded) change reports, and the agent's docs pushed to your own private repo
- **A security posture you can explain in one breath:** no way in, human gates on the way out, everything foreign is data.

## What you need

| | |
|---|---|
| Hardware | Apple-silicon Mac mini (16 GB+ RAM), always-on |
| Installer | [Claude Code](https://claude.com/claude-code) (Pro/Max) |
| Agent model | ChatGPT Pro (GPT-5.5 via Codex OAuth, flat-rate) — or adapt the provider in Phase 3 |
| Google Workspace | Your own domain, with a second user seat for the agent's identity |
| Slack | A free workspace is fine |
| OpenAI API key | Embeddings only (typically well under $5/mo) |
| Optional | Bland.ai (phone calls) · a private GitHub repo (docs self-backup) · Google Routes API (live-traffic ETAs) |

Plan a **full day** end-to-end (the reference build took ~1.5 days including tearing out a predecessor system and making every decision fresh — you're inheriting the decisions). The phases pause cleanly, so splitting across evenings works fine.

## Start

```bash
git clone https://github.com/scott-rippey/hermes-mini-setup.git
cd hermes-mini-setup
# open Claude Code here, then say: "let's begin"
```

`CLAUDE.md` is the installer's brain — phases, decision points, verification gates, and every gotcha we hit so you don't have to.

## Provenance

This is the sanitized, reproducible walkthrough of a real production system (built June–July 2026 on Hermes Agent v0.17.0). Every feature here runs daily on the original box; every gotcha in the appendix was hit for real. Nothing customer- or operator-specific was ever committed to this repo — the personalization phase generates *your* specifics locally.
