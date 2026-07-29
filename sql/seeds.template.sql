-- Seeds template — instantiated by the installer in Phase 0 from setup/answers.md.
-- Replace {{PLACEHOLDERS}} and save as sql/seeds.sql (setup/ output, never committed).
--
-- Two non-company identities anchor KB scoping:
--   {{OWNER_SLUG}}  -> the operator's own work (their "me" bucket; the tools' default)
--   general         -> AI/general research not tied to any customer
-- Everything else is created later, never seeded: real customers via the
-- customer-onboarding skill, and community identities (recurring groups the
-- operator belongs to — dev groups, masterminds; their meetings file under the
-- group itself) via add_customer with kind='community'.

INSERT INTO customers (slug, name, aliases)
VALUES
  ('{{OWNER_SLUG}}', '{{BUSINESS_NAME}}',
   ARRAY['{{OPERATOR_FIRST_NAME}}', 'me', 'my business']::text[]),
  ('general', 'General / AI research',
   ARRAY['research', 'ai']::text[])
ON CONFLICT (slug) DO NOTHING;
