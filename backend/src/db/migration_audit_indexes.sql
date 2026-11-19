-- migration_audit_indexes.sql
-- Adds performance indexes for audit_log filtering used by GET /api/admin/audit
-- (filters by action, entity, user_id, created_at). Safe to re-run.

CREATE INDEX IF NOT EXISTS idx_audit_action       ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_entity        ON audit_log(entity);
CREATE INDEX IF NOT EXISTS idx_audit_action_entity ON audit_log(action, entity);
CREATE INDEX IF NOT EXISTS idx_audit_entity_id    ON audit_log(entity_id);

-- Backfill ip_address for older rows (NULL stays NULL — nothing to do).
-- Add an index for activity-feed lookups by user + time.
CREATE INDEX IF NOT EXISTS idx_audit_user_created ON audit_log(user_id, created_at DESC);
