# Knowledge Base (KB) — Postgres RAG

> The knowledge corpus: customers, contacts, apps, meetings, documents, research — embedded and semantically searchable, entirely local. **Writes are human-gated: the agent offers to file, the operator decides.**

## Shape

- **DB:** local Postgres (Homebrew service, localhost-only), pgvector enabled. Built verbatim from [`sql/schema.sql`](../sql/schema.sql) + your generated seeds.
- **Server:** the custom MCP server ([templates/mcp-rag/](../templates/mcp-rag/README.md)) — **the only writer**. Tools: `mcp_rag_store / search / get / customers / add_customer / people / add_person / apps / add_app / add_meeting`.
- **Embeddings:** OpenAI `text-embedding-3-large` (3072-dim) on store; cosine search. (3072 exceeds pgvector's HNSW cap — fine at personal scale; `halfvec` is the scale path.)

## The identity model (no-drift by construction)

- **`customers`** — canonical companies, plus two non-company identities: the **operator's own slug** (their "me" bucket — also the silent default for unscoped stores) and **`general`** (non-customer research). Aliases resolve to canonical slugs; contacts are **never** company aliases.
- **`people`** — first-class contacts, linked to companies **many-to-many** with a per-company role. One person can span businesses — e.g., Jamie is "Owner" at Acme Gym *and* "Partner" at Acme Parking; `add_person` finds-or-links, never duplicates.
- **`apps`** — first-class software records, each owned by exactly ONE company, optionally carrying a GitHub `owner/name` (feeds the docs-sync).
- **`meetings`** — one row per real meeting (unique meeting-id dedupe), linked to customer/person and the searchable meeting doc.
- A document files under a **primary** company, optionally also a person and/or an app — and can **link to any number of additional people and companies** via the `document_people` / `document_customers` join tables (`people=` / `customers=` on `store` / `add_meeting`). Search scoped to a person or company matches any linked doc, so a multi-attendee meeting note surfaces under every attendee. Extras must already exist (no silent creates); a linked person at exactly one company links that company automatically. Installs created before this schema shipped: apply `sql/migrations/005_document_links_m2m.sql` (adds the join tables + backfills from the single columns), then update the mcp-rag server from the template.

## Scoping rules (learned from a real misfile)

Every store names an explicit scope: the operator's own work → their slug · non-customer research → `general` · client work → that customer. **An unscoped store silently lands in the operator's own bucket** — wrong for research, and exactly the kind of quiet misfile that's hard to find later. The research persona's prompt carries this warning verbatim; keep it there.

## What writes, and how it's gated

| Path | Gate |
|---|---|
| Agent filing anything from chat/research | **Offer-then-file** — present, ask scope, store only on an explicit yes |
| `file-to-kb` skill | Same gate, for uploads (Slack uploads arrive as *context*, never auto-filed) |
| Onboarding skills | Interview → present the profile → file on approval |
| `github-docs-sync` (nightly, optional) | **Sanctioned deterministic auto-write** — fixed repo→app mapping, zero AI judgment; its prune touches only its own GitHub-sourced docs, so hand-filed notes survive |
| `add_meeting` (nightly pipeline, optional) | Sanctioned deterministic write: notes → meetings row + doc under the resolved person→company |

## Ecosystem touchpoints

Nightly `pg_dump` rides the encrypted bundle · KB growth appears in the ops digest · **KB-first lookup is a SOUL rule** (an unfamiliar proper noun is more likely a customer than a public entity — check the KB before the web) · personas coordinate **through** the KB, never agent-to-agent.
