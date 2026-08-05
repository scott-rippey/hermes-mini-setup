-- 006: apps get aliases, same shape as customers/people — alternate names that
-- resolve to the same app (working titles, project codenames). Resolution in
-- server.py _resolve_app; merge-only semantics via add_app (like people).
ALTER TABLE apps ADD COLUMN IF NOT EXISTS aliases text[] NOT NULL DEFAULT '{}';
