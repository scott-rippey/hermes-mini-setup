---
name: contact-onboarding
description: Add one or more people (contacts) to an existing customer/company in the knowledge base (KB), or link an existing person to another company. A person can belong to several companies. Use when {{OPERATOR_FIRST_NAME}} wants to add/capture a contact at a company he already has in the KB, or attach someone who already exists to another company — without re-onboarding the whole company.
version: 1.0.0
author: hermes-mini-setup (reference build)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Contact, People, Onboarding, CRM, Knowledge Base, KB]
---

# Contact Onboarding

Add a person/contact to a company that already exists in {{OPERATOR_FIRST_NAME}}'s knowledge base (KB), or link an existing person to another of his companies. Trigger when {{OPERATOR_FIRST_NAME}} says things like "add a contact", "add a person to [company]", "new contact at [company]", "[name] is another contact at [company]", "[name] also works with [other company]", or "link [name] to [company]".

The KB is the local Postgres vector store reached through the `mcp_rag` tools (`customers`, `people`, `add_person`, `store`). People are first-class records linked to companies through a join — a person can belong to **several** companies, each with its own role. A contact is **never** stored as an alias on the company.

This skill is for adding people to a company that is **already onboarded**. If the company isn't in the KB yet, use **customer-onboarding** instead (it onboards the company and its first contacts together).

## Procedure

### 1. Resolve the company (it must already exist)

- Call `mcp_rag customers` and find the company {{OPERATOR_FIRST_NAME}} named (match on name or alias).
- If the company is **not** found, do not guess and do not create it from a contact. Tell {{OPERATOR_FIRST_NAME}} it isn't in the KB yet and offer to run **customer-onboarding** for the company first.

### 2. Interview {{OPERATOR_FIRST_NAME}} for the contact(s)

Capture each person. **Every field except the name is optional** — take whatever {{OPERATOR_FIRST_NAME}} gives; never block or nag. For each contact:

1. **Name** — the person's name.
2. **Role** — their title or role at the company.
3. **Email** — if known.
4. **Aliases** — other names {{OPERATOR_FIRST_NAME}} uses for them (nickname, first name only, etc.) that should resolve to this same person.
5. **Anything else** worth remembering (context, how {{OPERATOR_FIRST_NAME}} knows them, notes).

If {{OPERATOR_FIRST_NAME}} lists several people at once, handle them all.

### 3. Check whether the person already exists (anywhere)

Call `mcp_rag people` (omit `customer` to search **all** companies) and check whether this person already exists — match on name, email, or an alias. They may already be in the KB under a *different* company; if so, you're **linking that same person** to this company, not creating a new one. `add_person` handles both cases — it reuses an existing person and just adds the new company link (no duplicate).

### 4. Confirm + add

Show {{OPERATOR_FIRST_NAME}} the contact(s) you're about to add — name, role, email, aliases, and which company they attach to — and confirm before writing (present-then-file). On his confirmation, for each contact call `mcp_rag add_person`:
- `name` = the person's name
- `customer` = the company's name/slug
- `email` / `role` / `aliases` = whatever was provided

`add_person` finds-or-creates the person, then links them to this company. `role` is stored **per company** (the same person can be "Owner" at one and "Advisor" at another); `email` / `aliases` update the shared person record.

### 5. Offer to file any notes (do not auto-store)

If {{OPERATOR_FIRST_NAME}} gave context worth keeping (background, a meeting note, what they need), **offer** to file it as a document under that person — `mcp_rag store` with `person` = the contact's name/slug (attaches it to the person; if they belong to **one** company it's filed there automatically, if **several** also pass `customer` to say which). Only store on {{OPERATOR_FIRST_NAME}}'s explicit say-so; read-and-dismiss is the default.

Then tell {{OPERATOR_FIRST_NAME}} which contacts were added/updated and under which company.

## Notes
- The company must already exist — this skill never creates a company. Hand off to **customer-onboarding** if it doesn't.
- Optional fields are the norm — a name alone is a valid contact.
- Contacts are people linked to companies through a join (a person can belong to several companies), never company aliases.
- KB writes (the person record, and any note) happen only after {{OPERATOR_FIRST_NAME}} confirms.
