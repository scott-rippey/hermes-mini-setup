-- 005_document_links_m2m.sql — a document can link to MANY people and MANY companies.
-- memory_documents keeps its customer_id / person_id / app_id columns as the PRIMARY
-- link (where the doc is "filed" — unchanged semantics for existing consumers); the new
-- document_people / document_customers join tables carry the FULL link set (primary
-- included, via backfill), so a meeting note with two attendees from two companies is
-- findable under every one of them. Meetings need no join tables of their own:
-- meetings.document_id points at the KB doc, whose links are the source of truth.
-- Transactional: ON_ERROR_STOP + BEGIN/COMMIT.

\set ON_ERROR_STOP on
BEGIN;

-- 1. join table: document <-> person
CREATE TABLE document_people (
    document_id uuid NOT NULL REFERENCES memory_documents(id) ON DELETE CASCADE,
    person_id   uuid NOT NULL REFERENCES people(id)           ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (document_id, person_id)
);
CREATE INDEX idx_document_people_person ON document_people(person_id);

-- 2. join table: document <-> company
CREATE TABLE document_customers (
    document_id uuid NOT NULL REFERENCES memory_documents(id) ON DELETE CASCADE,
    customer_id uuid NOT NULL REFERENCES customers(id)        ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (document_id, customer_id)
);
CREATE INDEX idx_document_customers_customer ON document_customers(customer_id);

-- 3. backfill: every existing doc's primary links mirror into the join tables
INSERT INTO document_customers (document_id, customer_id)
SELECT id, customer_id FROM memory_documents WHERE customer_id IS NOT NULL;

INSERT INTO document_people (document_id, person_id)
SELECT id, person_id FROM memory_documents WHERE person_id IS NOT NULL;

COMMIT;
