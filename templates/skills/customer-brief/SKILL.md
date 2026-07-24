---
name: customer-brief
description: One-command grounded account snapshot of a customer — KB profile, contacts, apps, recent meetings, document inventory, pending e-signatures, and recent email activity, synthesized into a compact brief. Use when {{OPERATOR_FIRST_NAME}} asks "where are we with X", "brief me on X", "catch me up on X", or "what's the latest with X" for a customer/client/company.
version: 1.0.0
author: hermes-mini-setup (reference build)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Customer, Brief, CRM, Knowledge Base, KB, Account]
---

# Customer Brief

A grounded, read-only snapshot of one customer — the pre-meeting / pre-call "where are we with them" answer. Trigger on "where are we with X", "brief me on X", "catch me up on X", "customer brief for X".

**Read-only skill: it never writes to the KB, never sends anything.** No approval gates needed; just gather, synthesize, present.

## Procedure

### 1. Deterministic gather

```
python ~/.hermes/skills/productivity/customer-brief/scripts/brief_data.py "<customer name/slug/alias>"
```

Returns one JSON object: `customer` (identity + metadata), `people` (contacts w/ roles, primaries first), `apps`, `meetings` (latest 10), `kb_docs` (recent 15 + total), `pending_esign` (docs out for signature matched to this customer's people). On `error` it lists the known customer slugs — if the ask plausibly matches one, retry with that slug; otherwise tell {{OPERATOR_FIRST_NAME}} who IS known and stop.

### 2. Enrich (both, in parallel where possible)

- **KB content:** `mcp_rag search` scoped to the customer (`customer=<slug>`) with 2-3 queries shaped by what step 1 revealed — e.g. the latest meeting's topic, an active project/app, "proposal". You're after substance for the brief's "current threads", not a re-listing of titles.
- **Email:** search {{OPERATOR_FIRST_NAME}}'s mailbox (google-workspace gmail search) for recent threads with the customer's people — query their email addresses/domain, last ~30 days. Note who wrote last and whether anything looks unanswered.

### 3. Synthesize the brief

One compact Slack message, mobile-first (no wide tables). Shape:

- **Header** — company, stage/role relationship in one line (from KB profile metadata), since-date.
- **People** — name · role, primaries first, one line each.
- **Latest activity** — the 2-3 most recent meetings with a one-line takeaway each (pull the takeaway from the meeting doc content, not just its title), plus anything active found in email (who's waiting on whom).
- **Open items** — pending e-signatures (subject + sent-when), unanswered email threads, anything the KB content marks as blocked/next.
- **Assets** — apps (with repos) and the KB doc count, one line.
- **Gaps** — one line, honest: what the KB *doesn't* have (e.g. no meetings filed, profile thin), so {{OPERATOR_FIRST_NAME}} knows the confidence level.

Cite what came from where only when it matters (e.g. "per the 7/16 planning meeting"). Never pad; if a section is empty, drop it.

### 4. Offer, don't push

End with: offer a `deliverable-export` version (branded DOCX/PDF) if {{OPERATOR_FIRST_NAME}} wants it as a document — only produce it if he says yes.

## Notes

- Resolution accepts name, slug, or alias; a fuzzy fallback catches partials ("acme" → `acme-construction`).
- `pending_esign` only includes signature requests matched to this customer's people by email/name — an empty list means none for THIS customer, not none at all.
- Meetings and docs come from the structured tables (deterministic); narrative quality comes from your step-2 searches. Do both — the script alone under-informs the brief.
