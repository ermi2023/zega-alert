-- ============================================================
-- ZEGA-ALERT gap-fill migration
-- Aligns the database with the specification document:
-- logout token invalidation, People of Determination,
-- wanted/missing announcement types, legal review history,
-- social-share analytics.
-- Safe to run multiple times (idempotent).
-- ============================================================

-- 1. Logout / refresh-token invalidation (doc 3.3.3, SD-2)
--    Every token embeds a version; incrementing it invalidates all
--    outstanding access/refresh tokens for that user.
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0;

-- 2. Announcement categories: wanted & missing persons (doc 4.3.3)
ALTER TYPE announcement_type ADD VALUE IF NOT EXISTS 'wanted';
ALTER TYPE announcement_type ADD VALUE IF NOT EXISTS 'missing';

-- 3. Legal content review workflow (doc UC-16 / SD-9)
ALTER TABLE legal_content ADD COLUMN IF NOT EXISTS review_status VARCHAR(20) NOT NULL DEFAULT 'published';
ALTER TABLE legal_content ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE legal_content ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE legal_content ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE TABLE IF NOT EXISTS legal_review_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_id    UUID NOT NULL REFERENCES legal_content(id) ON DELETE CASCADE,
  action      VARCHAR(40) NOT NULL,
  from_status VARCHAR(20),
  to_status   VARCHAR(20),
  note        TEXT,
  changed_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_legal_history_legal ON legal_review_history(legal_id, created_at);

-- 4. Police stations (nearest-station lookup for People of Determination)
CREATE TABLE IF NOT EXISTS police_stations (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name      VARCHAR(150) NOT NULL,
  phone     VARCHAR(20),
  region    VARCHAR(100),
  sub_city  VARCHAR(100),
  latitude  DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stations_region ON police_stations(region, sub_city);

-- 5. People of Determination - direct call requests (doc UC-4)
CREATE TABLE IF NOT EXISTS direct_call_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  citizen_phone   TEXT,
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  station_id      UUID REFERENCES police_stations(id) ON DELETE SET NULL,
  station_name    VARCHAR(150),
  station_phone   VARCHAR(20),
  status          VARCHAR(20) NOT NULL DEFAULT 'requested',
  handled_by      UUID REFERENCES users(id) ON DELETE SET NULL,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  completed_at    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_direct_call_user ON direct_call_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_direct_call_status ON direct_call_requests(status);

-- 6. People of Determination - sign language video messages (doc UC-5)
CREATE TABLE IF NOT EXISTS sign_language_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  report_id   UUID REFERENCES reports(id) ON DELETE SET NULL,
  video_url   TEXT NOT NULL,
  note        TEXT,
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  status      VARCHAR(20) NOT NULL DEFAULT 'submitted',
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sign_lang_user ON sign_language_messages(user_id);

-- 7. Social media share analytics (doc UC-11)
CREATE TABLE IF NOT EXISTS share_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
  content_type VARCHAR(40) NOT NULL,
  content_id   UUID,
  platform     VARCHAR(40) NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_share_events_created ON share_events(created_at);

-- 8. Report statuses aligned to the design document
--    (Draft, Submitted, Under Review, Assigned, In Progress, Resolved, Rejected, Closed)
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'draft';
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'submitted';
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'assigned';
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'in_progress';
