# Google Workspace — the Two-Account Model

> The pattern that matters: **the operator's account reads, the agent's account acts** — two OAuth tokens with disjoint, minimal scopes. All Google runs inside your own Workspace domain; personal Gmail is never involved.

## The two tokens

| Token | Account | Scopes | Used for |
|---|---|---|---|
| `google_token_read.json` | **operator@your-domain** | `gmail.readonly`, `gmail.compose`, `tasks.readonly` | Reading the operator's real inbox + to-dos (brief, prep, on-demand) + creating **drafts in the operator's own Drafts folder** (`gmail draft-create` — the email-triage lane) |
| `google_token.json` | **agent@your-domain** | `gmail.send`, `calendar.readonly`, `calendar.events`, `drive.file` | Sending email *as the agent*, reading the operator's **shared** calendar, writing Drive (backups) |

Why split: reads against the operator's mailbox need their identity but **must not** be able to send as them; actions need an attributable, revocable identity that **cannot read their mail at all**. Either token revokes independently in one click. Bonus discipline: the agent's third-party signups (phone provider, research APIs) also live under the agent identity — its entire external footprint audits in one place.

## Setup (Phase 6)

1. **Workspace:** create the agent's user (e.g. `atlas@your-domain`); share the operator's calendar to it (the agent reads the *shared* calendar — its own calendar is the **invite-organizer surface**, see below).
2. **GCP:** one project; OAuth consent **Internal** (Workspace-only — skips unverified-app friction; note it *rejects* personal-Gmail logins by design); a desktop OAuth client; secret to `~/.hermes/google_client_secret.json`.
3. **Install the modified scripts** from [templates/google-workspace/](../templates/google-workspace/) over the bundled skill's — they add the per-op two-account routing, repeatable `--attach` + `--html` sending, and calendar attendees (meeting prep needs them).
4. **Auth both lanes:** `setup.py --account read` (as the operator) and `--account send` (as the agent). Adding a scope later = re-auth that account.
5. **Drafts policy (read account):** `gmail.compose` exists ONLY for `draft-create` — a draft in the operator's Drafts folder that THEY send. Google has no drafts-without-send scope (`compose` includes send), so drafts-only is enforced at the code layer: `google_api.py` implements **no send op on the operator@ path** (every send-type op is pinned to agent@ via `_SEND_OPS`). A send-as-operator would require a deliberate script edit.
6. **Operator signature on drafts:** create `~/.hermes/operator-signature.txt` (plain) and `.html` (rich) holding the operator's real email signature — `draft-create` appends them automatically (`--no-signature` opts out). Gmail only signs in its *compose UI*, so an API-created draft would otherwise send bare. Grab the exact wording/links from one of the operator's own recent sent emails rather than reconstructing it. Files sit in `HERMES_HOME`, outside the skill dir, so platform updates can't touch them; skills must never type a signature into the body.
7. **Invite lane (agent = organizer):** events are created on the **agent's own calendar** (`calendar create --calendar primary`) with the operator + guests as `--attendees`; the insert passes **`sendUpdates="all"`** — without it Google creates the event but emails NO ONE (the silent-failure mode; the shipped script handles it). Attendees get genuine Google invitations with RSVP chips; nothing writes to the operator's calendar. `calendar delete` sends cancellation notices the same way. RSVP status reads from the organizer copy (`attendees[].responseStatus`) — "who's accepted?" works from chat. Pin this in SOUL as the ONE canonical invite path (never hand-built "invitation emails"/.ics; failures reported, not worked around; non-operator attendees approval-gated). Pair with an Admin-console rename of the agent account (e.g. "Atlas (X's AI Assistant)") so the From/organizer name is honest everywhere. **Recipient gotcha:** a recipient whose per-calendar "Other notifications → New events" is set to None receives NO invitation email from anyone — the event still lands silently on their calendar. Google's default is Email; check the recipient's settings before debugging the sender.
8. **Send policy** (SOUL + convention): `gmail.send` exists to email **the operator only** — deterministic self-reports are auto-allowed; any other recipient is per-item approval. Approved external sends **and replies auto-CC the operator**: `_ensure_owner_cc` (called by both the send and reply paths) appends their address whenever it isn't already in To/Cc, so the copy survives even if the agent forgets the SOUL rule.

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
