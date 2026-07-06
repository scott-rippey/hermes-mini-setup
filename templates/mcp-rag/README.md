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
