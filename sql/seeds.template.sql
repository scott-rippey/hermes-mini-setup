-- Seeds template — instantiated by the installer in Phase 0 from setup/answers.md.
-- Replace {{PLACEHOLDERS}} and save as sql/seeds.sql (setup/ output, never committed).
--
-- Two non-company identities anchor KB scoping:
--   {{OWNER_SLUG}}  -> the operator's own work (their "me" bucket; the tools' default)
--   general         -> AI/general research not tied to any customer
-- Everything else (real customers) is created later via the customer-onboarding skill.

INSERT INTO customers (slug, name, aliases, notes)
VALUES
  ('{{OWNER_SLUG}}', '{{BUSINESS_NAME}}',
   ARRAY['{{OPERATOR_FIRST_NAME}}', 'me', 'my business']::text[],
   'The operator''s own work. Default scope — but every store should still name it explicitly.'),
  ('general', 'General / AI research',
   ARRAY['research', 'ai']::text[],
   'Non-customer research bucket. Research personas file here unless a customer is named.')
ON CONFLICT (slug) DO NOTHING;
