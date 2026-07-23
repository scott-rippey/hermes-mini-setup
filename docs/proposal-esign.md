# Proposals & Contracts E-Sign — SignWell Pipeline (optional, strongly recommended)

> The agent drafts a proposal in #proposals (KB + email grounded, discovery-first), renders it branded, and — behind a send-card gate — sends it for legally-binding e-signature via SignWell under the operator's own account. A 15-min poller catches the signature, saves the PDF, and asks in Slack whether to file it. Optional feature; recommend it to anyone who sends client proposals — it closes the #proposals loop draft→send→signed→filed.

## Decisions that shaped it

- **SignWell over DocuSign/Dropbox Sign:** usage-based API pricing — first 25 API documents/month free (card on file), sub-$1 pay-as-you-go after, no monthly minimum. The alternatives start at $50–75/mo standby cost, absurd for a few proposals a month. (Open-source self-hosting was rejected on posture: hosting the signing page means public ingress.)
- **Polling, not webhooks — zero ingress.** Signature completion is *polled* (same pattern as meeting prep); the signed PDF is pulled over the same API. No listener, no relay, nothing to secure.
- **The operator's account, not the agent's** — a deliberate exception to the agent-identity rule: this service sends *legal documents as the business*. Signature requests carry the operator's name/branding; the return email is theirs.
- **Text tags over coordinates.** The signature block lives IN the proposal markdown as white-on-white SignWell text tags (`{{signature:1:y}}` / `{{date:1:y}}` — literal tag syntax, not install placeholders); every rendered PDF is born signature-ready and SignWell auto-places the fields from the text layer. No per-document field setup.
- **Decide what a signed proposal MEANS** and make the acceptance language say it. The reference build's model: signing = agreement to move forward; a formal contract with payment terms follows. The skill's conversion rules encode this — adjust the sentence to the operator's deal model in Phase 0.

## The pieces

| Piece | Where | Notes |
|---|---|---|
| Skill | `templates/skills/proposal-esign/` → `~/.hermes/skills/productivity/proposal-esign/` | SKILL.md rules + `signwell.py` (`send` / `status` / `poll [--notify]`, stdlib-only) |
| API key | `SIGNWELL_API_KEY` in `~/.hermes/.env` (600) | Terminal ceremony — never through chat |
| Pending state | `~/.hermes/signwell/pending.json` | Docs awaiting signature; poll self-heals (deleted upstream → dropped) |
| Poller | launchd `ai.hermes.signwell-poll`, every 15 min, `poll --notify` | No-op when nothing pending; end-of-run marker; digest row ships in the digest template, gated on the skill dir |
| Signed PDFs | `~/<agent>-outputs/<date>-<doc>-SIGNED.pdf` | Local artifact. SignWell's dashboard keeps the audit trail AND emails the operator the signed copy itself — so the pipeline sends **no email** |
| Dashboard branding | SignWell Settings → Branding | Logo: use a **300×60 self-backgrounded lockup bar** (icon + wordmark on a dark rounded bar, transparent corners) — theme-proof on light webmail and dark-mode mobile, where a transparent logo fails one or the other. Business-tier feature; may lapse on the PAYG API tier after trial (the PDF's own branding is yours regardless) |

## The flow (two tracks)

1. **#proposals drafts** — the persona mandates KB + operator-email context, then a discovery exchange (found/missing brief + 2-4 framework questions) BEFORE drafting.
2. **Track A — verbal check:** the draft goes to the operator as an HTML email body; they edit and forward it themselves for a verbal yes. Conversational tone is correct here.
3. **Track B — official:** on "make it official", the skill converts — strip email framing → formal header, substance verbatim, Acceptance section (deal-model sentence + validity window) + hidden tags. **Client-presentable PDF filename** — it's the document title recipients see.
4. **Send-card gate:** before EVERY live send the agent posts recipient + exact PDF + subject and waits for a confirm — even when the instruction already named them (intent-approval ≠ artifact-approval). `test_mode: true` is a free full rehearsal — no billing, not binding, and the recipient address gets a banner-wrapped preview (how you check branding without a live send).
5. **Signature lands:** the poller detects it, saves the PDF, posts a file-ask to #proposals (`hermes send` — deterministic, no AI), prefixed with `<@member-id>` read from `SLACK_ALLOWED_USERS` in `.env` — a hard notification, self-configuring on any box. Interactive polls omit `--notify` so agent and cron never double-post.
6. **Offer-then-file:** the operator replies; the agent files md + metadata (doc id, signer, signed date, artifact paths) under the send-time customer with people/company links. Never auto-stored.

## Contract mode (one merged channel, not a second persona)

The proposals channel doubles as the contracts channel (`#proposals-contracts` in the reference build) — one persona, two document types, routed by "proposal" vs "contract" in the ask. The operator's deal motion decides what each signature MEANS: commonly a signed proposal = move forward, and the contract = the executed agreement (some clients get both, some contract-only). Two contract entry paths: **from a signed proposal** (substance carried verbatim, pared into contract language + the itemized Schedule A and payment mechanics the proposal deferred) or **contract-only** (terms discovery from scratch: itemized scope, total, payment plan, maintenance tiers, start date). The legal skeleton ships at `templates/skills/proposal-esign/references/contract-skeleton.md` — a generic services agreement personalized at install ({{BUSINESS_LEGAL_NAME}}, {{STATE}} governing law/mediation, the operator's IP stance — shipped default: provider owns the work product + tools, client gets a perpetual non-transferable internal-use license that survives termination, no resale) — **recommend a one-time attorney review**; the agent is drafter-not-counsel and client redlines go to the operator. Contract signatures EXECUTE the agreement (never move-forward acceptance language). Same send-card gate, poller, and offer-then-file loop.

## Ops notes

- Persona changes (config.yaml channel prompts) need a gateway restart + a NEW session; **skill changes are live on the next invocation** (Hermes reads SKILL.md from disk at trigger time).
- The completed-PDF endpoint can 400 for a few seconds right after signing; the poller retries next cycle.
- Declined/Expired → posted to #proposals; no automatic follow-up.
- Nothing here is reverted by `hermes update` (local skill + config + launchd all survive).
