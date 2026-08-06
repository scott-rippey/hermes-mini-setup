-- 007_maintenance_layer.sql — KB maintenance layer: status lifecycle, usage tracking,
-- metadata backfill. FRESH INSTALLS DON'T NEED THIS — sql/schema.sql already carries the
-- columns, constraint, and column-scoped trigger. Apply only to an install created before
-- the maintenance layer shipped. Pre-req: pg_dump backup (standing rule).
-- Idempotent; runs in one transaction.
--
-- Design:
--   * status: active -> superseded/archived, human-decided only; hard delete = manual psql only.
--   * last_used_at / retrieval_count: bumped by the server on search/get returns.
--   * Trigger scoped to content-bearing columns so usage bumps NEVER reset updated_at
--     (updated_at is the staleness signal). Shared function update_updated_at_column()
--     is untouched (meetings uses it too).
--   * metadata.type closed enum: customer_profile | app_profile | meeting | repo_doc |
--     research | reference | note.  metadata.source: github | granola | slack | upload | agent.

\set ON_ERROR_STOP on
BEGIN;

-- ---------------------------------------------------------------- columns
ALTER TABLE memory_documents ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
ALTER TABLE memory_documents ADD COLUMN IF NOT EXISTS superseded_by uuid REFERENCES memory_documents(id);
ALTER TABLE memory_documents ADD COLUMN IF NOT EXISTS last_used_at timestamptz;
ALTER TABLE memory_documents ADD COLUMN IF NOT EXISTS retrieval_count integer NOT NULL DEFAULT 0;

ALTER TABLE memory_documents DROP CONSTRAINT IF EXISTS memory_documents_status_check;
ALTER TABLE memory_documents ADD CONSTRAINT memory_documents_status_check
    CHECK (status IN ('active', 'superseded', 'archived'));

-- ------------------------------------------------------------ drop trigger
-- Dropped BEFORE the backfill so the metadata UPDATEs below don't stamp
-- updated_at = now() on every backfilled row (updated_at is the staleness
-- signal — the backfill must not look like fresh edits). Recreated, column-
-- scoped, at the END of this migration.
DROP TRIGGER IF EXISTS update_memory_documents_updated_at ON memory_documents;

-- ---------------------------------------------------------------- backfill
-- EACH INSTALL MAPS ITS OWN LEGACY VALUES. Survey what's in the store first:
--   SELECT metadata->>'type', metadata->>'source', count(*) FROM memory_documents
--   GROUP BY 1, 2 ORDER BY 3 DESC;
-- then write idempotent UPDATEs mapping every legacy/missing type and source onto the
-- closed enums above, HERE (between the trigger drop and the trigger recreate — the
-- ordering is load-bearing, see the drop-trigger comment). Example shapes:
--
-- -- github-synced repo docs
-- UPDATE memory_documents SET metadata = metadata || '{"type":"repo_doc"}'
-- WHERE metadata->>'source' = 'github'
--   AND metadata->>'type' IS DISTINCT FROM 'repo_doc';
--
-- -- normalize a drifted source value
-- UPDATE memory_documents SET metadata = metadata || '{"source":"slack"}'
-- WHERE metadata->>'source' = 'some-legacy-slack-value';
--
-- -- type an untyped doc family by title pattern
-- UPDATE memory_documents SET metadata = metadata || '{"type":"customer_profile"}'
-- WHERE metadata->>'type' IS NULL AND path LIKE 'Customer Profile — %';

-- ------------------------------------------------- trigger: column-scoped
-- Usage-tracking UPDATEs (last_used_at, retrieval_count) must not bump updated_at.
CREATE TRIGGER update_memory_documents_updated_at
    BEFORE UPDATE OF path, content, metadata, customer_id, person_id, app_id, status
    ON memory_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------- assert
-- Uncomment and run AFTER writing your own backfill above — it fails the
-- transaction if any doc is left off-enum (the server will refuse such stores
-- going forward, but pre-existing rows must be mapped by hand).
-- DO $$
-- DECLARE bad integer;
-- BEGIN
--     SELECT count(*) INTO bad FROM memory_documents
--     WHERE metadata->>'type' IS NULL
--        OR metadata->>'type' NOT IN ('customer_profile','app_profile','meeting','repo_doc','research','reference','note');
--     IF bad > 0 THEN
--         RAISE EXCEPTION 'backfill incomplete: % docs without a valid type', bad;
--     END IF;
--     SELECT count(*) INTO bad FROM memory_documents
--     WHERE metadata->>'source' IS NOT NULL
--       AND metadata->>'source' NOT IN ('github','granola','slack','upload','agent');
--     IF bad > 0 THEN
--         RAISE EXCEPTION 'backfill incomplete: % docs with off-enum source', bad;
--     END IF;
-- END $$;

\echo '007 applied: status model + usage columns + scoped trigger (write your own backfill — see comments)'
COMMIT;
