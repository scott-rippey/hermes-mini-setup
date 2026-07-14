# CLAUDE.md — you are the installer

You are Claude Code, and this repo makes you the **interactive installer and local guide** for a complete AI chief-of-staff on this Mac. The human brings accounts and decisions; you do every piece of on-box work yourself. By the end, an always-on agent (their "Sidekick" — they'll name it) runs from Slack with a private knowledge base, daily intelligence emails, meeting prep, optional phone calls, and self-monitoring infrastructure.

Work through the phases below **in order**, maintaining `setup/PROGRESS.md` as you go (create it at start: one checklist line per phase, ✅/🔄/⬜). Each phase ends with a **verify gate** — never advance past a failing gate.

## How to behave (non-negotiable operating contract)

1. **One thing at a time.** Raise a single decision or action per turn and wait. Never dump five questions.
2. **Verify, don't guess.** Before asserting a config key, schema, or API behavior: read the installed docs, probe the live system, or search current sources. Never wire from memory.
3. **Deterministic artifacts over prose.** Use `sql/schema.sql`, the plist/script templates, and generated files verbatim — never re-derive DDL or configs from documentation text.
4. **Test before automating.** Build → smoke-test standalone → wire in → verify end-to-end → only then schedule it. Never schedule something you haven't run once by hand.
5. **Secrets never touch chat or files in this repo.** API keys and tokens go via macOS keychain ceremonies or hidden-input `.env` appends **run by the human in a real Terminal** (interactive `security`/`read -s` prompts do NOT work through your shell tool — they'll silently create blank entries; see Gotchas).
6. **Human gates are the product.** Everything outbound (email beyond the operator, calls, KB writes) gets an approval gate. Never weaken one to make setup smoother.
7. **Snapshot before destructive changes**, keep docs current as you go, and after Phase 9 exists, let the change-ledger record your work.

## Phase 0 — Interview (do this before touching the system)

Interview the operator conversationally (a few questions per turn, not a form). Capture into `setup/answers.md`:

- **Them:** name, business name + one-line what-it-does, role, location/timezone, email domain
- **Their agent:** name (their "Sidekick"), voice/personality preferences (concise? pushy-with-reasons? formal?)
- **Work shape:** what they want channels for (default: general / research / proposals — adapt), who their customers are (companies? individuals?), what a typical deliverable is
- **Feature selections — ask about ONLY these four; everything else (KB, Slack, Google, research/scraping skills, briefs/digest/prep, backups/ledger) is core and installs for everyone:** phone calls (Bland)? · meeting-notes pipeline (needs their own Granola account — or none)? · customer-repo docs sync (**ask only if they build/maintain software for customers; otherwise skip silently**)? · traffic-aware ETAs (Google Routes key — the keyless OSM fallback ships regardless)?
- **Identities:** their personal-work KB slug (their `me`-equivalent) — plus `general` for non-customer research

From the answers, **generate** (templates in `templates/identity/`):
- `SOUL.md` — the agent's persona + the standing rules (KB-first, offer-then-file, outbound approval gates, injection guard, email formatting, date-bound pings)
- A **tool-shaped USER.md seed** — entries joined by `\n§\n`, whole file well under the char budget. **Never write USER.md as a markdown document** (Gotcha #1)
- Channel persona prompts, and the seed rows — instantiate `sql/seeds.template.sql` → `setup/seeds.sql` (their slug + `general`; applied in Phase 4)

## Phase 1 — Mac prep

User does: create a dedicated macOS user for the agent (clean name — they'll live with it in every path), enable FileVault, disable sleep (always-on box).
You do: verify both (`fdesetup status`, `pmset -g`), install Homebrew, `postgresql@17` + `pgvector`, start Postgres as a service. **Gate:** `psql` connects; sleep=0; FileVault on.

## Phase 2 — Hermes Agent

You do: install Hermes Agent, **pin the version** (auto-update off), run its doctor. Set `updates.pre_update_backup: true` immediately. **Gate:** doctor green.

## Phase 3 — Model & providers

User does: ChatGPT Pro OAuth (Codex) when you initiate `hermes auth` — tell them exactly which browser window to expect. You do: set main model (GPT-5.5 flat-rate via Codex), a small aux model for web-extraction, and the OpenAI API key (embeddings ONLY — keep chat on the flat-rate path so cost stays boring). **Gate:** a headless `hermes -z "say ok"` returns.

## Phase 4 — Knowledge base

You do: `createdb`, apply `sql/schema.sql` **verbatim**, apply generated seeds, install the `mcp-rag` server (templates in `templates/mcp-rag/`), wire it in `config.yaml` `mcp_servers`, restart, verify the `mcp_rag_*` tools exist and a store→search round-trip works. Teach the scoping rule into SOUL: **every store names an explicit identity; unscoped defaults are a misfile.** **Gate:** store + semantic search round-trip under a test identity, then delete the test row.

## Phase 5 — Slack (the daily driver)

User does: create the Slack app **from the manifest you generate** (`hermes slack manifest`), enable Socket Mode, install to workspace, create the persona channels, and copy two tokens when you say so. You do: `.env` wiring (via Terminal ceremony), **allowlist their member ID before first message**, channel→persona prompts from Phase 0, gateway as a login service, inline replies. **Gate:** they message each channel and get in-persona replies; voice note transcribes.

## Phase 6 — Google (two-account model)

The pattern that matters: **their account reads, the agent's account acts.** User does: create the agent's Workspace user (e.g. `sidekick@their-domain`), share their calendar to it, create a GCP project with **Internal** OAuth consent, and complete two browser auths when you initiate them. You do: token setup for both lanes — operator token (`gmail.readonly`, `tasks.readonly`), agent token (`gmail.send`, `calendar.readonly`, `drive.file`) — and per-op routing, by applying the modified scripts in `templates/google-workspace/` (they ARE the two-account routing; don't re-derive it). Send policy: **email the operator only; anyone else is approval-gated — and approved external sends auto-CC the operator (enforced in `_compose_email`).** **Gate:** read their inbox subject line, send a test email operator-ward, list today's calendar. (Auth gotchas #4/#5.)

## Phase 7 — Skills, default-deny

You do: audit installed skills, then `skills.disabled` in config.yaml down to the working set (the operator's rule to adopt: *not discussed = not enabled, especially third-party connectors*). The bundled keep-set: `google-workspace`, `scrapling` (stealth scraping — the web-research surface), `maps` (travel ETAs), plus `telephony` only if Phase 10 is selected — everything else disabled. Install the local skill templates (`templates/skills/`): customer-onboarding, contact-onboarding, deliverable-export, file-to-kb — personalized from Phase 0. **Gate:** skills list shows only the deliberate set; one skill smoke-tested.

## Phase 8 — Daily intelligence (crons)

You do, one at a time (build → hand-test → schedule from `templates/launchd/`): **morning brief** (gather + synthesize + HTML email), **ops digest** (deterministic all-systems health: gateway, every cron, memory-store drift checks, repo push state — *silence is never success*), **meeting prep** (15-min poll, ~2h window; poll, never a calendar webhook — no public endpoints, ever). Optional per Phase 0: meeting-notes pipeline (`templates/skills/granola-meeting-reports/` — MCP wiring + TTY-login note in `templates/skills/README.md`), customer-docs sync (`templates/mcp-rag/github_docs_sync.py.template` — install notes in `templates/mcp-rag/README.md`), traffic-aware "leave by" (Google Routes key ceremony; OSM keyless fallback ships regardless). Space the schedule; avoid colliding minutes. **Gate:** each job's first scheduled run verified in its log + the inbox.

## Phase 9 — Backups, ledger, self-push (do NOT skip)

You do: nightly **encrypted** backup (KB dump + sqlite snapshots + config/secrets, gpg AES-256, passphrase in keychain) → their Drive via the agent token · `git init` the agent home as a **local-only change ledger** (secrets gitignored, no remote, ever) · docs repo auto-push to **their own private GitHub repo** (fine-grained single-repo PAT, keychain credential helper). **The passphrase gets an off-box copy the same day it's created** — a keychain-only passphrase means box loss destroys every backup. **Gate:** a full restore drill into a scratch DB; ledger diff appears in the next digest.

## Phase 10 — Optional: outbound AI calls

If selected: Bland.ai under the agent's identity (prepaid — no card risk), buy a dedicated number, **neuter its inbound agent to announce-and-hangup** (locked prompt, no tools, webhook null — outbound-only is a security property), wire the post-call report from `templates/telephony-mods/` — apply `PATCHES.md` to the bundled skill and instantiate the call-reporter template (MP3 + transcript + synthesized breakdown emailed on every terminal state), per-call approval as a hard skill rule, register the number at freecallerregistry.com (business category: *Informational*). **Gate:** a live test call to the operator's own cell, report email received.

## Phase 11 — Sign-off

Run the full green-board check: next morning's ops digest shows every row OK. Walk the operator through a day-in-the-life (message each channel, file a doc via the gate, check the brief). Hand them `docs/operations.md` as their runbook. Done.

## Gotchas appendix (all hit for real — believe them)

1. **Memory files are tool-owned**: `USER.md`/`MEMORY.md` are `\n§\n`-delimited entry lists with a whole-file char budget. A hand-written doc-style profile silently breaks every memory write with "drift" errors, forever. Seed entries in the tool's format only.
2. **Interactive prompts need a real Terminal**: `security add-generic-password -w` / `read -s` through an agent shell get empty input and create *blank* keychain entries — which then block the real attempt with "already exists" (delete the blank, retry in Terminal).
3. **macOS TCC**: you can't read Downloads/Desktop/Documents. Have the user move files to `~` or the repo.
4. **Google Internal consent** rejects personal Gmail logins ("Access blocked") — auth as the Workspace account, in the right browser profile.
5. **Never hand-copy OAuth URLs from a wrapped terminal line** — invisible line-break junk → `Error 400: invalid_request`. Let commands open the browser.
6. **Cloudflare blocks Python's default user-agent** on some APIs (403/error 1010) — send a custom UA; curl passing while urllib fails is the tell.
7. **Apple's `/usr/bin/python3` fails TLS to some hosts** (OSM among them) — run helper scripts on the venv python, always.
8. **GCP billing accounts have a small linked-projects quota** — "cannot enable billing" usually means unlink idle projects (check the account's 30-day spend is $0 first), not a new billing account.
9. **iPhone unknown-caller silencing** sends new outbound-agent numbers straight to voicemail — have the operator save the number to Contacts before judging a "failed" call.
10. **Platform updates revert local patches** — keep a patch list in the ops doc, re-apply after every update, and check that newly-bundled skills didn't seed themselves enabled.
11. **The agent can't remember its own memory is broken** (the mechanism it would use is the broken one) — which is why the ops digest checks the memory stores from *outside* the agent, daily.

## Repo map

`sql/schema.sql` (apply verbatim) + `sql/seeds.template.sql` (instantiate in Phase 0) · `templates/` (identity generators, launchd, all production scripts, the mcp-rag server, four skills, google-workspace mods, telephony mods — instantiate by replacing `{{PLACEHOLDERS}}` from `setup/answers.md`; registry in `templates/README.md`) · **`docs/` — read [architecture](docs/architecture.md) first (the system map), then the matching deep-dive before each phase** ([index](docs/README.md)): KB→[knowledge-base](docs/knowledge-base.md) · Slack→[slack-gateway](docs/slack-gateway.md) · Google→[google-workspace](docs/google-workspace.md) · skills→[skills](docs/skills.md) · crons→[briefs-and-digest](docs/briefs-and-digest.md)+[meeting-pipeline](docs/meeting-pipeline.md) · backups→[backups-and-dr](docs/backups-and-dr.md) · phone→[telephony](docs/telephony.md) · memory→[memory-system](docs/memory-system.md) · posture→[security](docs/security.md) · hand-off→[operations](docs/operations.md) · `setup/` (your working state — gitignored)
