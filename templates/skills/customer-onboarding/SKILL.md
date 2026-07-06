---
name: customer-onboarding
description: Onboard a customer or client into the knowledge base (KB) through a short guided interview, then file a structured profile attached to the canonical customer record. Use when {{OPERATOR_FIRST_NAME}} wants to add, onboard, set up, capture, or create a new customer / client / company in the KB.
version: 1.1.0
author: hermes-mini-setup (reference build)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Customer, Onboarding, CRM, Knowledge Base, KB]
---

# Customer Onboarding

Guided onboarding of a customer/client into {{OPERATOR_FIRST_NAME}}'s knowledge base (KB). Trigger when {{OPERATOR_FIRST_NAME}} says things like "onboard a customer", "add a customer/client", "set up [company] in the KB", or "capture a new customer".

The KB is the local Postgres vector store reached through the `mcp_rag` tools (`customers`, `add_customer`, `people`, `add_person`, `store`, `search`, `get`). Customer info belongs in the KB — never in built-in memory. A customer is the **company/identity**; its **contacts are people** linked to the company through a join (a person can belong to **several** companies, each with its own role) — and is never stored as a company alias.

## Procedure

### 1. Interview {{OPERATOR_FIRST_NAME}}

Capture the customer's profile. **Every field is optional** — take whatever {{OPERATOR_FIRST_NAME}} gives, in whatever order; never block or nag on missing info. Ask all at once or conversationally. Mark anything not provided as "(not provided)".

1. **Name** — the customer/company name + any aliases for the **company** (a DBA, short name, or other name for the *company itself*). A person's name is a contact, captured below — never a company alias.
2. **Industry** — what they do.
3. **Key contact(s)** — name, role, email.
4. **What they need** — the problem, opportunity, or project.
5. **Stage** — e.g. lead, evaluating, active, won, paused, lost.
6. **Budget & timeline** — if known.
7. **Relationship type + history** — how {{OPERATOR_FIRST_NAME}} knows them, the kind of relationship, and any background/history.
8. **Apps / software** — any apps tied to this customer? For each: app name + GitHub repo (`owner/name`), plus a one-line description if handy. Most customers won't have one — skip if none.
9. **Anything else** worth remembering.

### 2. Resolve the canonical customer/company (avoid duplicates)

- Call `mcp_rag customers` to list existing customers and check whether this company already exists (match on the name OR any alias). If it exists, reuse that canonical record — do NOT create a duplicate; you are updating their profile.
- If genuinely new, call `mcp_rag add_customer` with the name and any **company** aliases (alternate names for the *company* — a DBA or short name). **Never put a person's name in the company aliases** — contacts become people in the next step.

### 3. Add the contacts as people

For each key contact {{OPERATOR_FIRST_NAME}} gave, call `mcp_rag add_person` with the contact's `name`, the `customer` (this company's name/slug), and `email` / `role` if known. This **links** the person to this company (a person can be linked to several companies, each with its own role). If the contact already exists in the KB — even at a different company — `add_person` reuses that person and just adds this company link (no duplicate). People are first-class records, never company aliases. (If there are no contacts yet, skip this step.)

### 4. Assemble + confirm

Build a clean Markdown profile with a heading per field above (omit or mark fields not provided). **Show it to {{OPERATOR_FIRST_NAME}} and ask him to confirm before saving**, and confirm which customer it attaches to. Never invent details he didn't give.

### 5. File to the KB

On {{OPERATOR_FIRST_NAME}}'s confirmation, call `mcp_rag store`:
- `content` = the structured profile Markdown
- `title` = `Customer Profile — <Name>` (one canonical profile per customer; re-onboarding the same customer updates it)
- `customer` = the customer's name/slug (attaches it to the canonical record)

Then tell {{OPERATOR_FIRST_NAME}} what was saved, under which customer, and which contacts you added as people. The research and proposals personas can now build on this profile.

## Notes
- Optional fields are the norm — partial profiles are expected and fine.
- Writes to the KB only after {{OPERATOR_FIRST_NAME}} confirms (consistent with the present-then-file rule).
- For later additions (research, notes, docs), use `mcp_rag store` scoped to the same customer name/slug.
- **Avoid dead-info carryover.** When {{OPERATOR_FIRST_NAME}} mentions another customer only because he is about to create that customer's own profile, do not preserve extra "Anything Else" reminders like "create X separately" after he says they are unnecessary. Keep cross-customer context only where it remains useful (relationship, app ownership, collaboration model).
- **Use {{OPERATOR_FIRST_NAME}}'s corrected status language.** If he says a business is paused rather than inactive, file it as paused. Preserve nuanced operational notes like "runs the business, exact title unknown" rather than inventing a formal title.
- **Podcast/media details matter.** If {{OPERATOR_FIRST_NAME}} clarifies cadence or format (e.g. bi-weekly audio + video podcast), include that in the relevant app/media entry.
- **Apps during customer onboarding are notes.** If {{OPERATOR_FIRST_NAME}} names customer apps while onboarding, list them under an "Apps" heading (app name + `owner/name` repo if known). Do **not** call `add_app` or touch GitHub credentials unless {{OPERATOR_FIRST_NAME}} explicitly asks to register an app.
- **Filing an app profile — during onboarding OR when adding an app to an existing customer.** When {{OPERATOR_FIRST_NAME}} explicitly registers an app and describes it (either flow): create the canonical record with `add_app` (repo may be null until it's wired), then file the summary as a KB doc titled `App Profile — <name>`, attached to the app (`app=<slug>`), metadata `{type: app_profile}`. Never invent repos. These per-app profiles are preserved by the github-docs-sync (it only prunes its own GitHub-sourced docs), so they sit safely alongside the synced repo docs.
