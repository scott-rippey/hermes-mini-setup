# Docs — the deep dives

The installer (root `CLAUDE.md`) references these per phase; the operator keeps them as the system's manual afterward. Every doc describes the shape the installer builds, including the real incidents that shaped it.

| Doc | What it covers | Backs phase |
|---|---|---|
| [architecture.md](architecture.md) | The one-page system truth: stack, jobs, repos, posture | all |
| [security.md](security.md) | No-ingress table, outbound gates, injection rules, secrets, supply chain, incident log | all |
| [web-research.md](web-research.md) | Firecrawl backend (primary) vs the scrapling skill (fallback): which scrapes what | 3, 7 |
| [knowledge-base.md](knowledge-base.md) | The KB: identity model, scoping discipline, write gates | 4 |
| [slack-gateway.md](slack-gateway.md) | The Slack app, Socket Mode, personas, gateway ops | 5 |
| [google-workspace.md](google-workspace.md) | The two-account model: operator reads, agent acts | 6 |
| [skills.md](skills.md) | Default-deny policy, the working set, the patch ledger | 7 |
| [briefs-and-digest.md](briefs-and-digest.md) | The two morning emails: synthesized vs. deterministic | 8 |
| [meeting-pipeline.md](meeting-pipeline.md) | Notes → KB, the prep poller, traffic-aware "leave by" | 8 |
| [backups-and-dr.md](backups-and-dr.md) | The nightly trilogy, restore drills, the passphrase rule | 9 |
| [memory-system.md](memory-system.md) | The four memory lanes + the drift incident that teaches them | 0, 9 |
| [telephony.md](telephony.md) | Outbound calls: approvals, reports, the neutered inbound | 10 |
| [proposal-esign.md](proposal-esign.md) | Proposals & contracts via SignWell: send-card gate, contract mode, the collection poller | 10b |
| [operations.md](operations.md) | The operator's runbook: rhythm, ceremonies, troubleshooting | 11 → forever |
