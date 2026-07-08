# mcp-rag — the KB server (install notes)

The custom MCP server that gives the agent its knowledge-base hands: `mcp_rag_store / search / get / customers / add_customer / people / add_person / apps / add_app / add_meeting`. It embeds on store (OpenAI `text-embedding-3-large`), searches via pgvector cosine, and enforces the identity model (alias→canonical resolution, find-or-link people, one-business apps, meeting dedupe). **It is the ONLY writer of the KB tables — keep it that way.**

## Install (installer does this in Phase 4)

```bash
mkdir -p ~/.hermes/mcp-rag && cd ~/.hermes/mcp-rag
# instantiate server.py from server.py.template (fill {{PLACEHOLDERS}}, verify none remain)
python3 -m venv .venv
.venv/bin/pip install "mcp>=1.28" "openai>=2" "psycopg[binary]>=3.3" "pgvector>=0.4" tiktoken
```

Reference versions from the production build (2026-07): mcp 1.28.1 · openai 2.44.0 · psycopg 3.3.4 · pgvector 0.4.2.

## Environment

| Var | Meaning | Default in template |
|---|---|---|
| `PGDATABASE` / `PG_DSN` | KB database | `{{KB_DB_NAME}}` |
| `RAG_NAMESPACE` | `memory_documents.user_id` scoping value | `{{AGENT_SLUG}}` |
| `RAG_DEFAULT_CUSTOMER` | Fallback identity for unscoped stores (the misfile catcher — personas must still scope explicitly) | `{{OWNER_SLUG}}` |
| `OPENAI_API_KEY` | Embeddings only | from `~/.hermes/.env` |

## Wire into the agent (`config.yaml`)

```yaml
mcp_servers:
  rag:
    command: /Users/{{MAC_USERNAME}}/.hermes/mcp-rag/.venv/bin/python
    args:
      - /Users/{{MAC_USERNAME}}/.hermes/mcp-rag/server.py
    enabled: true
```

Restart the gateway after wiring.

## Verify (Phase 4 gate)

1. Agent lists tools → all `mcp_rag_*` present.
2. Store a test doc under a test identity → semantic-search finds it → `get` returns it → delete the test row.
3. Confirm the scoping rule made it into SOUL: every store names an explicit customer/identity.

## Optional: GitHub docs-sync (`github_docs_sync.py.template`)

The nightly, **deterministic / no-AI** cron that keeps the KB current on the operator's own apps: for every `apps` row with a `repo`, it pulls `CLAUDE.md` + `docs/**` into the KB under that app. A **sanctioned auto-write** (fixed repo→app mapping, no agent judgment) — distinct from the human-gated filing tools.

What makes it cheap and safe (keep these properties when adapting):
- **SHA change-detection:** each doc's git blob SHA is stored in its KB metadata; unchanged files are skipped — no download, no re-embed, no cost. The only API call for an unchanged repo is one tree listing.
- **Prune is scoped to `metadata->>'source' = 'github'`** — docs the agent or operator filed under an app are never deleted when the repo changes.
- **Read-only PATs, one per GitHub owner**, in the keychain as `github-pat-<owner>` (account `{{AGENT_SLUG}}`): fine-grained, Contents:read only. The operator creates each PAT and stores it via the **Terminal keychain ceremony** (Gotcha #2 — never through the agent shell).

Install (Phase 8, if selected):
1. Instantiate next to `server.py` (it imports `server` for `_store`/`_connect`/namespace).
2. Register each app: `add_app` with its `owner/repo`, then the PAT ceremony for any new owner.
3. Hand-test: `.venv/bin/python github_docs_sync.py <app-slug>` — expect `added`/`unchanged` lines and a per-app summary.
4. Schedule nightly via `templates/launchd/job.plist.template` (reference: `ai.hermes.github-docs-sync` @ 9pm, before the 10pm meeting-reports run).
