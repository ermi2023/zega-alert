-- ============================================================
-- ZEGA-ALERT defence-alignment migration
-- Brings an existing database in line with the proposal/defence document.
-- Safe to run multiple times (idempotent).
-- ============================================================

-- Announcement categories: road closures & missing items (doc 4.3.3)
ALTER TYPE announcement_type ADD VALUE IF NOT EXISTS 'road_closure';
ALTER TYPE announcement_type ADD VALUE IF NOT EXISTS 'missing_item';

-- Missing persons require regional-admin authorization before public listing (doc 4.3.2 / SD-7)
ALTER TABLE missing_persons ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;
ALTER TABLE missing_persons ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE missing_persons ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
ALTER TABLE missing_persons ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
CREATE INDEX IF NOT EXISTS idx_missing_approved ON missing_persons(is_approved);

-- Geofence sensitivity / pause / owner + max-10 per citizen (doc 4.3.4)
ALTER TABLE geofences ADD COLUMN IF NOT EXISTS sensitivity VARCHAR(20) DEFAULT 'medium';
ALTER TABLE geofences ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE geofences ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_geofences_owner ON geofences(created_by);

-- Status history: every report status transition with timestamp + notes (doc 4.8.1)
CREATE TABLE IF NOT EXISTS status_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  status      report_status NOT NULL,
  notes       TEXT,
  changed_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_status_history_report ON status_history(report_id, created_at);

-- Dispatch ETA / distance (doc SD-4, collaboration diagram steps 6-11)
ALTER TABLE dispatch_assignments ADD COLUMN IF NOT EXISTS distance_m DOUBLE PRECISION;
ALTER TABLE dispatch_assignments ADD COLUMN IF NOT EXISTS eta_seconds INTEGER;

-- PII columns now hold AES-256-GCM ciphertext, which is longer than the
-- original column limits allowed. Widen them to TEXT.
ALTER TABLE missing_persons ALTER COLUMN contact_phone TYPE TEXT;
ALTER TABLE sos_alerts ALTER COLUMN address_text TYPE TEXT;

-- Post-conversation satisfaction rating (doc 4.3.5)
CREATE TABLE IF NOT EXISTS chat_ratings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment         TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (conversation_id, user_id)
);
