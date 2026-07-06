# Google Workspace — the Two-Account Model

> The pattern that matters: **the operator's account reads, the agent's account acts** — two OAuth tokens with disjoint, minimal scopes. All Google runs inside your own Workspace domain; personal Gmail is never involved.

## The two tokens

| Token | Account | Scopes | Used for |
|---|---|---|---|
| `google_token_read.json` | **operator@your-domain** | `gmail.readonly`, `tasks.readonly` | Reading the operator's real inbox + to-dos (brief, prep, on-demand) |
| `google_token.json` | **agent@your-domain** | `gmail.send`, `calendar.readonly`, `drive.file` | Sending email *as the agent*, reading the operator's **shared** calendar, writing Drive (backups) |

Why split: reads against the operator's mailbox need their identity but **must not** be able to send as them; actions need an attributable, revocable identity that **cannot read their mail at all**. Either token revokes independently in one click. Bonus discipline: the agent's third-party signups (phone provider, research APIs) also live under the agent identity — its entire external footprint audits in one place.

## Setup (Phase 6)

1. **Workspace:** create the agent's user (e.g. `atlas@your-domain`); share the operator's calendar to it (the agent reads the *shared* calendar — its own stays empty, reserved as the future identity for invites).
2. **GCP:** one project; OAuth consent **Internal** (Workspace-only — skips unverified-app friction; note it *rejects* personal-Gmail logins by design); a desktop OAuth client; secret to `~/.hermes/google_client_secret.json`.
3. **Install the modified scripts** from [templates/google-workspace/](../templates/google-workspace/) over the bundled skill's — they add the per-op two-account routing, repeatable `--attach` + `--html` sending, and calendar attendees (meeting prep needs them).
4. **Auth both lanes:** `setup.py --account read` (as the operator) and `--account send` (as the agent). Adding a scope later = re-auth that account.
5. **Send policy** (SOUL + convention): `gmail.send` exists to email **the operator only** — deterministic self-reports are auto-allowed; any other recipient is per-item approval.

## Auth gotchas (earned)

- Authorize as the **Workspace** account — Internal consent rejects personal Gmail ("Access blocked"). Use the right browser profile.
- **Never hand-copy an OAuth URL from a wrapped terminal line** — invisible line-break junk → `Error 400: invalid_request`. Let the command open the browser.

## Who uses which lane

| Consumer | Lane |
|---|---|
| Morning brief | read operator mail/tasks + shared calendar → **send** to operator |
| Ops digest / call reports / deliverables | send (with attachments) |
| Meeting prep | calendar + read mail → send |
| Encrypted backup | `drive.file`: upload/search/prune the backups folder |

## After platform updates

`hermes update` stashes local changes to bundled-skill scripts — **re-apply the modified scripts from this repo** (that's part of why they ship here), then restart the gateway. The ops digest confirms the lanes next morning (brief + digest arriving = both tokens working).
