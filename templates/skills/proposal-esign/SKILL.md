---
name: proposal-esign
description: Send a rendered proposal or contract (or any PDF) out for e-signature via SignWell under {{OPERATOR_FIRST_NAME}}'s {{BUSINESS_NAME}} account, track it, and retrieve the signed PDF. Use when {{OPERATOR_FIRST_NAME}} approves sending a proposal or contract for signature, asks to check signature status, a signed document needs collecting, or a contract needs drafting (references/contract-skeleton.md).
version: 1.0.0
author: {{BUSINESS_NAME}}
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [Proposal, Signature, ESign, SignWell, Contract]
    related_skills: [deliverable-export]
    category: productivity
---

<!-- NOTE for installers: the double-brace strings {{signature:1:y}} and {{date:1:y}}
     below are SignWell TEXT TAGS, not install placeholders — leave them verbatim. -->

# Proposal E-Sign — SignWell

Send proposals for legally-binding e-signature and collect the signed PDF. The SignWell account is **the operator's own** ({{OPERATOR_EMAIL}}, "{{BUSINESS_NAME}}") — signature requests reach clients *as the business*. Helper: `scripts/signwell.py` (API key `SIGNWELL_API_KEY` in `~/.hermes/.env`; billing: first 25 API docs/month free with a card on file, then pay-as-you-go).

## RULE 1 — every LIVE send stops at a send-card (no exceptions)

Before ANY `--live` send call, post a **send-card** and WAIT for {{OPERATOR_FIRST_NAME}}'s explicit confirm of THAT card:

> **Ready to send for signature — confirm?**
> • Recipient: <name> <email>
> • Document: <exact PDF filename> (<pages> pp)
> • Subject: <subject line>

This applies **even when the instruction already named the recipient and said to send** — that approved the intent, but the card is the operator's last look at the exact rendered artifact before it leaves (intent-approval ≠ artifact-approval). Approval of a previous send never carries over. `test_mode` sends (no email, no billing, not legally binding) still deserve a heads-up but don't require the card.

## Procedure

### 1. Draft and render the proposal
**Gather context from ALL sources first, not just the KB:** the KB (customer/person/meeting docs — search via the customer and linked people), **{{OPERATOR_FIRST_NAME}}'s email** (`google_api.py gmail search` — threads with/about the client, pricing discussions, commitments; reads of the operator's own mailbox are auto-allowed), and recent meetings (`meetings` table / meeting reports). Then draft per the #proposals playbook and render the PDF with the **deliverable-export** skill (pandoc + weasyprint + brand CSS). The proposal Markdown MUST end with the signature block (tags invisible — white on white — but present in the text layer; SignWell auto-places the fields from them):

```markdown
**Client signature:**

<span style="color:#ffffff">{{signature:1:y}}</span>

**Date signed:**

<span style="color:#ffffff">{{date:1:y}}</span>
```

**Converting a draft into the OFFICIAL version.** Proposals often start life as a
conversational email draft (sent to the operator, forwarded for a verbal yes). On
"make it official / send for signature", transform it — don't just append tags to
the letter:
- Strip email framing (salutation, "To/From/Subject" lines, sign-off) → formal
  document header: title, **Prepared for** (client + company), **Prepared by**
  ({{OPERATOR_NAME}} · {{BUSINESS_NAME}}), date.
- Keep the agreed substance verbatim — pricing, scope, and terms that got the verbal
  are settled; do not rewrite them.
- End with the doc-type's correct closing — **the two types sign DIFFERENT things**:
  - **PROPOSAL** → an **Acceptance** section matching the operator's deal model — if
    a signed proposal means agreement to MOVE FORWARD (not a work authorization),
    say so: "By signing below, [Client] accepts this proposal and agrees to move
    forward. A formal agreement covering payment terms and conditions will follow."
    Add a validity window ("This proposal is valid for 30 days from the date
    above." — adjust per the operator), then the signature block.
  - **CONTRACT** → NO move-forward language: a contract signature EXECUTES the
    agreement. Contracts are drafted from **`references/contract-skeleton.md`**
    (clause set, the operator's IP/license position, payment-plan defaults, and the
    signatures section — its agent-guidance section is binding; personalize it at
    install from Phase 0 answers). The skeleton already ends in the correct
    signature block.

### 2. Send for signature (after the GO — Rule 1)

**Name the PDF for the client's eyes.** The filename (minus `.pdf`) is the document title the recipient sees in the email and signing page — e.g. `Proposal - Workflow Automation - {{BUSINESS_NAME}}.pdf`, never a slugged internal name.

```bash
python "${HERMES_HOME:-$HOME/.hermes}/skills/productivity/proposal-esign/scripts/signwell.py" send \
  --pdf ~/{{AGENT_SLUG}}-outputs/<the-proposal>.pdf \
  --name "<Recipient Name>" --email "<recipient@example.com>" \
  --subject "<subject>" --message "<short message>" \
  --customer "<kb-customer-slug>" \
  --live
```

Omit `--live` for a test-mode rehearsal (creates the document, sends nothing, bills nothing — the recipient address still receives a banner-wrapped PREVIEW email, useful for checking branding). The send is recorded in `~/.hermes/signwell/pending.json` for tracking.

### 3. Track / collect

```bash
python .../signwell.py poll          # check ALL pending docs (interactive — no --notify)
python .../signwell.py status --id <doc_id>   # one doc
```

A **15-min launchd poller** (`ai.hermes.signwell-poll`, runs `poll --notify`) watches pending docs in the background: on a signed doc it downloads the PDF to `~/{{AGENT_SLUG}}-outputs/<date>-<doc>-SIGNED.pdf` and posts a file-ask (with an @-mention) to the proposals channel — the target comes from `SIGNWELL_NOTIFY_CHANNEL` in `.env` (set it to the channel ID: rename-proof). **No email is sent — SignWell itself emails the operator the signed copy.** When a signature lands (via the cron's Slack post, or `"result": "signed"` from your own poll):
1. **Offer** to file the proposal (markdown + signed date + SignWell doc id + signer) into the KB under the customer — offer-then-file, never auto-store.
2. Offer to draft the project kickoff for approval.

`Declined` / `Expired`: the cron posts it to the same channel; no automatic follow-up.

## Notes
- Signed docs also remain in the operator's SignWell dashboard (full audit trail) — the API and GUI are the same account.
- SignWell dashboard branding (Account Settings → Branding): upload a logo — a **300×60 self-backgrounded lockup bar** (icon + wordmark on a dark rounded bar, transparent corners) stays legible on BOTH light webmail and dark-mode mobile, where a transparent logo fails one or the other.
- The completed-PDF endpoint can 400 for a few seconds right after signing; `poll` just retries on its next run.
- Interactive polls omit `--notify` (you're already talking to the operator — the Slack post would duplicate you).
