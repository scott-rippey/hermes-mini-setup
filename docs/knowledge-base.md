# Knowledge Base (KB) — Postgres RAG

> The knowledge corpus: customers, contacts, apps, meetings, documents, research — embedded and semantically searchable, entirely local. **Writes are human-gated: the agent offers to file, the operator decides.**

## Shape

- **DB:** local Postgres (Homebrew service, localhost-only), pgvector enabled. Built verbatim from [`sql/schema.sql`](../sql/schema.sql) + your generated seeds.
- **Server:** the custom MCP server ([templates/mcp-rag/](../templates/mcp-rag/README.md)) — **the only writer**. Tools: `mcp_rag_store / search / get / check_overlap / customers / add_customer / people / add_person / apps / add_app / add_meeting`.
- **Embeddings:** OpenAI `text-embedding-3-large` (3072-dim) on store. (3072 exceeds pgvector's HNSW cap — fine at personal scale; `halfvec` is the scale path.)
- **Search is HYBRID:** every query runs BOTH cosine-vector similarity AND Postgres full-text (`content_tsv` generated tsvector + GIN — already in `sql/schema.sql`; `websearch_to_tsquery`, so quoted phrases work), merged by **reciprocal-rank fusion** (k=60; no cross-method score normalization). Keyword catches exact terms/proper nouns embeddings miss; each result carries `match: vector|keyword|both`. An empty/stopword-only keyword branch degrades gracefully to vector-only.
- **Results are one-per-DOCUMENT with small-to-big context:** chunk hits dedupe to their best-ranked document (no more one doc's chunks eating every slot). Content returned: the **full document** when ≤ `RAG_FULL_DOC_CHARS` (default 6000 chars — most KB docs fit) labeled `context: full_document`, else the matched chunk ± one neighbor labeled `context: window` (the agent calls `get` for the rest). Candidate pool = `max(limit×3, 15)` chunks per branch before fusion/dedup.

## The maintenance layer (status, staleness, conflicts)

**Governing invariant: no document's status ever changes without the operator's explicit decision.** The system flags; the operator decides. No timers, no auto-decay, no auto-merge; hard delete is a manual psql action only.

- **Metadata contract (server-enforced on store):** `metadata.type` is REQUIRED — `customer_profile · app_profile · meeting · repo_doc · research · reference · note`. `metadata.source` (optional) — `github · granola · slack · upload · agent`. `type: research` also requires `as_of: "YYYY-MM"`. The type derives the maintenance class: `repo_doc` self-maintains (nightly sync), `meeting` is forever-history, `*_profile` is current-state (the staleness risk), `research`/`reference`/`note` are dated snapshots. Signed proposals/contracts file as `reference` with `document_type` carrying the kind.
- **Status lifecycle:** `active → superseded | archived` (`status` + `superseded_by` on `memory_documents`). Search and the default `get` path return **active only**; a pointed `get` on a non-active doc still works and says why it's hidden. `store` takes `supersedes=<id-or-title>` — files the new doc AND flips the old one **in one transaction** (no separate cleanup step an agent can falsely claim).
- **Usage tracking:** the server bumps `last_used_at`/`retrieval_count` on every doc returned by `search`/`get`. The `updated_at` trigger is **column-scoped** so usage bumps never reset it — `updated_at` stays a pure staleness signal.
- **Gate-time conflict surfacing:** before any filing offer, the agent runs `check_overlap` (draft content + scope → top ≤3 similar active docs, floor 0.45 cosine, `RAG_OVERLAP_SIM_FLOOR`). Overlaps go INTO the offer: **supersede / merge / keep both / skip** — the operator classifies in the approval conversation they're already having. Merge = the agent drafts an integrated rewrite, the operator approves, re-store under the existing title (+ a one-line `metadata.history` entry). The check soft-fails: an error never blocks a filing.
- **Maintenance pass:** [`templates/scripts/kb_maintenance.py.template`](../templates/scripts/kb_maintenance.py.template) — on-demand, flag-only report run by hand (health stats · stale profiles >90d with usage signals · research by `as_of` · contract violations · near-dup pairs ≥0.80 with agent-model merge-vs-distinct proposals). Manual-first; **no launchd job** — schedule nothing until the report proves useful.
- **Built-in memory content audit** (the non-KB sibling): weekly, Mondays, riding the `system_changes.py` job — see [memory-system.md](memory-system.md).
- Fresh installs get all of this from `sql/schema.sql`. Installs created before the maintenance layer shipped: apply `sql/migrations/007_maintenance_layer.sql` (columns + column-scoped trigger; **write your own metadata backfill** — the file explains how), then update the mcp-rag server from the template.

## The identity model (no-drift by construction)

- **`customers`** — canonical companies, plus non-company identities: the **operator's own slug** (their "me" bucket — also the silent default for unscoped stores), **`general`** (non-customer research), and **community identities** (`metadata.kind = "community"`) — recurring groups the operator belongs to (dev groups, masterminds) whose meetings/knowledge file under the group itself, one identity per group (`add_customer` takes an optional `kind`; `customers` returns it so the agent can tell communities from paying customers). Aliases resolve to canonical slugs; contacts are **never** company aliases.
- **`people`** — first-class contacts, linked to companies **many-to-many** with a per-company role. One person can span businesses — e.g., Jamie is "Owner" at Acme Gym *and* "Partner" at Acme Parking; `add_person` finds-or-links, never duplicates.
- **`apps`** — first-class software records, each owned by exactly ONE company, optionally carrying a GitHub `owner/name` (feeds the docs-sync) and **aliases** — working titles / codenames that resolve to the same app (`add_app` takes `aliases=`, merge-only like people; migration `006_app_aliases.sql` for existing installs). The docs-sync skips binary assets (images/media/fonts/pdf) and files >400KB that sometimes live under `docs/`, and one bad file can't abort an app's sync.
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
