-- ============================================================
-- ZEGA-ALERT Spec Alignment Migration
-- Brings the database into 100% alignment with PDF specification:
-- Figure 19 (Class Diagram), Figure 24 (Database Schema),
-- Section 4.8.1 (PostgreSQL Tables via Supabase),
-- Section 4.8.2 (Notifications & SystemConfig),
-- and Figure 30 (Missing & Wanted Person case codes).
-- Idempotent and safe to run repeatedly.
-- ============================================================

-- 1. Roles table (Figure 24 / Doc 4.8.1)
CREATE TABLE IF NOT EXISTS roles (
  id               SERIAL PRIMARY KEY,
  role_name        VARCHAR(50) UNIQUE NOT NULL,
  description      TEXT,
  permission_level INT NOT NULL
);

INSERT INTO roles (id, role_name, description, permission_level)
VALUES
  (1, 'citizen', 'Citizen Public Access', 1),
  (2, 'police', 'Regional Police Officer', 2),
  (3, 'dispatcher', 'Emergency Dispatcher', 3),
  (4, 'regional_admin', 'Regional Administrator', 4),
  (5, 'system_admin', 'System Super Administrator', 5)
ON CONFLICT (id) DO UPDATE SET
  role_name = EXCLUDED.role_name,
  description = EXCLUDED.description,
  permission_level = EXCLUDED.permission_level;

-- Ensure users table has role_id FK (Figure 24)
ALTER TABLE users ADD COLUMN IF NOT EXISTS role_id INTEGER REFERENCES roles(id) ON DELETE SET NULL;

-- Backfill existing user role_ids
UPDATE users u
SET role_id = r.id
FROM roles r
WHERE r.role_name = u.role::text AND u.role_id IS NULL;

-- 2. Media Attachments table (Figure 24 / Doc 4.8.1)
CREATE TABLE IF NOT EXISTS media_attachments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID REFERENCES reports(id) ON DELETE CASCADE,
  file_url    VARCHAR(500) NOT NULL,
  file_type   VARCHAR(50) NOT NULL,
  uploaded_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_attachments_report ON media_attachments(report_id);

-- 3. System Config table (Figure 19 Class Diagram / Figure 24)
CREATE TABLE IF NOT EXISTS system_config (
  id            SERIAL PRIMARY KEY,
  setting_name  VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  last_modified TIMESTAMPTZ DEFAULT now()
);

-- Seed default policy in system_config if not present
INSERT INTO system_config (setting_name, setting_value)
VALUES ('security_policy', '{"password_min_length":8,"session_timeout_minutes":60,"rate_limit_per_minute":100,"tls_enforced":true,"encryption_at_rest":true}')
ON CONFLICT (setting_name) DO NOTHING;

-- 4. Notifications table (Figure 24 / Doc 4.8.2)
CREATE TABLE IF NOT EXISTS notifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  title         VARCHAR(200) NOT NULL,
  body          TEXT NOT NULL,
  delivery_type VARCHAR(50) DEFAULT 'push',
  is_read       BOOLEAN DEFAULT FALSE,
  metadata      JSONB DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- 5. Case codes for Missing Persons (MP-XXXX) and Wanted Persons (WP-XXXX) (Figure 30)
ALTER TABLE missing_persons ADD COLUMN IF NOT EXISTS case_code VARCHAR(20);
ALTER TABLE wanted_persons ADD COLUMN IF NOT EXISTS case_code VARCHAR(20);

-- Backfill case_code for existing records
UPDATE missing_persons
SET case_code = 'MP-' || UPPER(SUBSTRING(REPLACE(id::text, '-', '') FROM 1 FOR 4))
WHERE case_code IS NULL;

UPDATE wanted_persons
SET case_code = 'WP-' || UPPER(SUBSTRING(REPLACE(id::text, '-', '') FROM 1 FOR 4))
WHERE case_code IS NULL;

-- 6. Trigger to auto-generate case_code on insert
CREATE OR REPLACE FUNCTION set_person_case_code() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.case_code IS NULL THEN
    IF TG_TABLE_NAME = 'missing_persons' THEN
      NEW.case_code := 'MP-' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', '') FROM 1 FOR 4));
    ELSE
      NEW.case_code := 'WP-' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', '') FROM 1 FOR 4));
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_missing_case_code ON missing_persons;
CREATE TRIGGER trg_missing_case_code BEFORE INSERT ON missing_persons
  FOR EACH ROW EXECUTE FUNCTION set_person_case_code();

DROP TRIGGER IF EXISTS trg_wanted_case_code ON wanted_persons;
CREATE TRIGGER trg_wanted_case_code BEFORE INSERT ON wanted_persons
  FOR EACH ROW EXECUTE FUNCTION set_person_case_code();
