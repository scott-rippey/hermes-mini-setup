# Skills — Catalog, Policy, Patch Tracking

> Governing policy: **default-deny.** The reference operator's rule, worth adopting verbatim: *"the stuff we built is WHY I'm doing this system — if we haven't talked about it, we're probably not doing it, especially with a third-party connector."* Every enabled skill should have a story.

## Why it matters

Platforms ship dozens of bundled skills **enabled by default** — the reference build found 79 of 80 on, including screen control (computer-use), iMessage and FindMy, six GitHub write-capable skills, a second email client (an ungated send path!), and launchers for autonomous coding agents. Each enabled skill is capability surface running as the box user, plus noise in the skill selector.

## Mechanism

Enable/disable = the **`skills.disabled` list in `config.yaml`** + a gateway restart. There is **no** CLI disable subcommand — the list is the mechanism. Names come from each SKILL.md's frontmatter `name:` (directory names sometimes differ). Re-enable = delete one line. ⚠️ **Platform updates seed newly-bundled skills as ENABLED** — re-check the list after every update. Also set the background skill **curator off** — no robo-editor should touch a hand-curated set.

## The working set (reference build: 9 enabled)

| Skill | Source | Job |
|---|---|---|
| customer-onboarding | this repo | Interview → canonical customer + contacts-as-people |
| contact-onboarding | this repo | Add/link people (many-to-many, per-company role) |
| deliverable-export | this repo | Markdown → branded DOCX/PDF → scratch dir → optional email/KB |
| file-to-kb | this repo | The offer-then-file gate for uploads |
| proposal-esign | this repo | Optional: proposals out for e-signature via SignWell + the 15-min collection poller ([proposal-esign.md](proposal-esign.md)) |
| meeting-reports | your build (optional) | The nightly meeting pipeline |
| google-workspace | bundled **(modified — this repo ships the mods)** | All Google I/O |
| telephony | official **(modified — see telephony-mods/)** | Outbound calls (optional) |
| scrapling | official | Hard-page fallback to the built-in web tools (whose Firecrawl backend is wired in Phase 3 — see [web-research.md](web-research.md)) |
| maps | bundled | OSM geocode/route — keyless; powers the travel fallback + live "route me from anywhere" asks |

## The patch ledger (keep one; this is yours pre-filled)

| Where | Changes | Reverted by | Re-apply from |
|---|---|---|---|
| google-workspace (bundled) | Two-account routing, `--attach`/`--html`, calendar attendees | **platform update** | [templates/google-workspace/](../templates/google-workspace/) |
| telephony (official, installed copy) | UA fix, caller-ID, reporter, rules 7–8 | skill **reinstall** only | [templates/telephony-mods/](../templates/telephony-mods/PATCHES.md) |
| Platform core (optional hardening) | See [operations.md](operations.md) §core patches | **platform update** | operations.md descriptions |

## Conventions for building your own

Skills shell out to a symlinked `python` → the platform venv (deps resolve). Volatile state under the skill's `state/` dir. KB writes always through `mcp_rag` with explicit scope, behind offer-then-file. **Skill before cron:** build → test the mechanic standalone → enable → verify discovery (`hermes skills list`) → restart → only then schedule anything on it.
