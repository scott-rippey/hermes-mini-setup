---
name: file-to-kb
description: File a document {{OPERATOR_FIRST_NAME}} has shared — an uploaded file (PDF, DOCX, CSV, image, etc.), pasted text, or something already in the conversation — into the knowledge base (KB), correctly scoped to a customer, person, or app, with a clean title and type. Use when {{OPERATOR_FIRST_NAME}} says "file this", "save this to the KB", "add this to [customer]'s docs", "put this under [person/app]", or otherwise asks to store a shared document in the knowledge base.
version: 1.0.0
author: hermes-mini-setup (reference build)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Knowledge Base, KB, Filing, Documents, Upload, RAG, CRM]
---

# File to KB

File a document {{OPERATOR_FIRST_NAME}} has shared into his knowledge base (KB), scoped to the right customer / person / app, with a clean title and type. Trigger when {{OPERATOR_FIRST_NAME}} says things like "file this", "save this to the KB", "add this to [company]'s docs", "file this under [person]", "store this for the [app] project", or "keep this in the KB".

The KB is the local Postgres vector store reached through the `mcp_rag` tools (`customers`, `people`, `apps`, `store`, `search`, plus `add_*` for onboarding). Documents belong in the KB — **never** in built-in memory. On `store`, the document is chunked and embedded for semantic search; `title` is the unique key (re-storing the same title replaces that document).

**This skill is the offer-then-file gate.** An uploaded file is read into the conversation as context automatically — that is *not* filing. You file only when {{OPERATOR_FIRST_NAME}} asks, and only after he confirms the plan. Never auto-store; read-and-dismiss is the default.

## Procedure

### 1. Identify the document

The content is usually already in the conversation — an uploaded file (its text extracted; an image read via vision), pasted text, or something synthesized earlier. Use that. If it's ambiguous which thing {{OPERATOR_FIRST_NAME}} means to file, ask. If he shared several, handle each (confirm the set first).

### 2. Resolve the scope — this is the important step

Every document lands under exactly one of: a **customer** (company), the **general** identity (AI / general research), or **{{OWNER_SLUG}}** ({{OPERATOR_FIRST_NAME}}'s own). It may *also* attach to a **person** and/or an **app**. Get this right — a wrong scope is a misfiled, hard-to-find KB entry, and an unscoped `store` silently defaults to `{{OWNER_SLUG}}`.

- Take the scope from {{OPERATOR_FIRST_NAME}}'s instruction ("under Acme", "for a contact", "the Acme Portal app", "general research").
- Resolve it to a canonical record first: `mcp_rag customers`, `mcp_rag people` (omit `customer` to search everyone), or `mcp_rag apps` — match on name, slug, or alias. Reuse the canonical record; don't create a near-duplicate.
- **person → company:** if you're filing under a person who belongs to one company, it attaches there automatically; if they belong to **several**, also pass `customer` to say which. **app → company:** an app derives its company automatically.
- **If {{OPERATOR_FIRST_NAME}} didn't say where, or it's ambiguous, ASK** — don't guess the scope. (Only fall back to `general`/`{{OWNER_SLUG}}` when {{OPERATOR_FIRST_NAME}} explicitly says general / his own.)
- **If the customer / person / app genuinely isn't in the KB yet, don't silently create it from a filing.** Tell {{OPERATOR_FIRST_NAME}} and offer to onboard first — **customer-onboarding** (new company), **contact-onboarding** (new person), or `add_app` (new app) — then file.

### 3. Derive a clean title + type

- **Title** — clear, specific, human, and unique; it's the upsert key. e.g. `Acme — MSA proposal (2026-06)`, `Acme Portal — pricing spec`. If you're updating a document that already exists, reuse its exact title so it replaces rather than duplicates (check with `search`).
- **Type** — classify: `proposal`, `contract`, `notes`, `research`, `report`, `spec`, `reference`, `invoice`, etc. Goes in metadata.
- **Date** — if the document has a meaningful date, note it (in the title and/or metadata).

> Filing a **meeting**? Use **`add_meeting`** instead of `store` (it also creates the structured `meetings` row). This skill is for general documents.

### 4. Normalize the content

Pass clean text to `store` — strip repeated headers/footers, page furniture, and export boilerplate, but keep the real structure (headings, lists, tables as text) so it chunks and embeds well. For an image, file the vision-extracted text / a faithful description of what it shows.

### 5. Present the filing plan + confirm (the gate)

Show {{OPERATOR_FIRST_NAME}} exactly what you'll do before writing:

> "I'll file **‹title›** under **‹Acme → Jane / general / the Acme Portal app›** as a **‹type›**. OK?"

Store **only** on his explicit yes. If he says no / not now, drop it — nothing is written.

### 6. Store

Call `mcp_rag store`:
- `content` = the normalized text
- `title` = the title from step 3
- `customer` / `person` / `app` = the resolved scope (pass `customer` alongside `person` when the person spans several companies)
- `metadata` = `{ "type": "‹type›", "source": "upload" }` (plus a `date` if relevant)

### 7. Confirm + verify

Report back: the title, where it landed (customer → person/app), and that it's now searchable. Optionally run a quick `mcp_rag search` (scoped to that customer/person/app) to confirm the new content comes back. Tell {{OPERATOR_FIRST_NAME}} it's filed.

## Notes
- **Never auto-store.** Filing happens only on {{OPERATOR_FIRST_NAME}}'s explicit ask *and* confirmation (steps 5–6). Reading an upload into the conversation is not filing.
- **Always scope explicitly.** An unscoped `store` defaults to `{{OWNER_SLUG}}` — confirm the scope rather than letting it default by accident.
- **Don't create companies / people / apps from a filing** — hand off to the onboarding skills / `add_app`, then file.
- `title` is the upsert key — reuse it to update, change it to add a new document.
- Meetings → `add_meeting`. Plain documents → `store`. Built-in memory is never used for documents.
