-- ============================================================
-- ZEGA-ALERT Database Schema
-- Crime Reporting, Missing Person Finder & Emergency Assistance
-- PostgreSQL 18
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------
-- ENUM TYPES
-- ------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'role_type') THEN
    CREATE TYPE role_type AS ENUM ('citizen', 'police', 'dispatcher', 'regional_admin', 'system_admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_status') THEN
    CREATE TYPE report_status AS ENUM ('draft', 'pending', 'submitted', 'under_review', 'assigned', 'in_progress', 'verified', 'rejected', 'resolved', 'closed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_severity') THEN
    CREATE TYPE report_severity AS ENUM ('low', 'medium', 'high', 'critical');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sos_status') THEN
    CREATE TYPE sos_status AS ENUM ('triggered', 'acknowledged', 'dispatched', 'resolved', 'cancelled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'person_status') THEN
    CREATE TYPE person_status AS ENUM ('missing', 'found', 'wanted', 'captured');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'announcement_type') THEN
    CREATE TYPE announcement_type AS ENUM ('news', 'warning', 'legal', 'event', 'road_closure', 'missing_item', 'wanted', 'missing');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'translation_lang') THEN
    CREATE TYPE translation_lang AS ENUM ('en', 'am', 'om', 'ti');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_type') THEN
    CREATE TYPE message_type AS ENUM ('text', 'image', 'audio', 'location');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_type') THEN
    CREATE TYPE conversation_type AS ENUM ('direct', 'group');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'otp_purpose') THEN
    CREATE TYPE otp_purpose AS ENUM ('register', 'login', 'reset_password', 'verify_phone');
  END IF;
END $$;

-- ------------------------------------------------------------------
-- ROLES (Figure 24 / Doc 4.8.1)
-- ------------------------------------------------------------------
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

-- ------------------------------------------------------------------
-- USERS (citizens + staff)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name          VARCHAR(150) NOT NULL,
  phone              VARCHAR(20) UNIQUE,
  email              VARCHAR(150) UNIQUE,
  password_hash      TEXT,
  role               role_type NOT NULL DEFAULT 'citizen',
  role_id            INTEGER REFERENCES roles(id) ON DELETE SET NULL,
  region             VARCHAR(100),
  sub_city           VARCHAR(100),
  woreda             VARCHAR(100),
  photo_url          TEXT,
  device_token       TEXT,
  preferred_language VARCHAR(10) DEFAULT 'en',
  accessibility_mode BOOLEAN DEFAULT FALSE,
  is_verified        BOOLEAN DEFAULT FALSE,
  is_active          BOOLEAN DEFAULT TRUE,
  token_version      INTEGER NOT NULL DEFAULT 0,
  last_login_at      TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

-- ------------------------------------------------------------------
-- OTP CODES (phone/email verification)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS otp_codes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact      VARCHAR(150) NOT NULL,
  code         VARCHAR(6) NOT NULL,
  purpose      otp_purpose NOT NULL DEFAULT 'login',
  expires_at   TIMESTAMPTZ NOT NULL,
  used_at      TIMESTAMPTZ,
  attempts     INTEGER DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_otp_contact ON otp_codes(contact, purpose);

-- ------------------------------------------------------------------
-- REPORTS (crime reports)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  category        VARCHAR(80) NOT NULL,
  severity        report_severity NOT NULL DEFAULT 'medium',
  status          report_status NOT NULL DEFAULT 'pending',
  title           VARCHAR(200) NOT NULL,
  description     TEXT,
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  address_text    VARCHAR(300),
  region          VARCHAR(100),
  sub_city        VARCHAR(100),
  woreda          VARCHAR(100),
  is_anonymous    BOOLEAN DEFAULT FALSE,
  evidence        JSONB DEFAULT '[]'::jsonb,
  assigned_to     UUID REFERENCES users(id) ON DELETE SET NULL,
  priority_score  INTEGER DEFAULT 0,
  reported_at     TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now(),
  resolved_at     TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_region ON reports(region, sub_city);
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);

-- ------------------------------------------------------------------
-- STATUS HISTORY (full audit trail of every report status transition)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS status_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  status      report_status NOT NULL,
  notes       TEXT,
  changed_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_status_history_report ON status_history(report_id, created_at);

-- ------------------------------------------------------------------
-- MEDIA ATTACHMENTS (Figure 24 / Doc 4.8.1)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS media_attachments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID REFERENCES reports(id) ON DELETE CASCADE,
  file_url    VARCHAR(500) NOT NULL,
  file_type   VARCHAR(50) NOT NULL,
  uploaded_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_attachments_report ON media_attachments(report_id);

-- ------------------------------------------------------------------
-- SOS ALERTS (emergency dispatch)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sos_alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  address_text  VARCHAR(300),
  description   TEXT,
  status        sos_status NOT NULL DEFAULT 'triggered',
  region        VARCHAR(100),
  sub_city      VARCHAR(100),
  woreda        VARCHAR(100),
  contacted_1   VARCHAR(20),
  contacted_2   VARCHAR(20),
  dispatcher_id UUID REFERENCES users(id) ON DELETE SET NULL,
  response_notes TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  resolved_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sos_status ON sos_alerts(status);
CREATE INDEX IF NOT EXISTS idx_sos_created ON sos_alerts(created_at);

-- ------------------------------------------------------------------
-- MISSING PERSONS
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS missing_persons (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_code        VARCHAR(20),
  name             VARCHAR(150) NOT NULL,
  age              INTEGER,
  gender           VARCHAR(20),
  photo_url        TEXT,
  description      TEXT,
  last_seen_lat    DOUBLE PRECISION,
  last_seen_lng    DOUBLE PRECISION,
  last_seen_address VARCHAR(300),
  last_seen_at     TIMESTAMPTZ,
  reporter_id      UUID REFERENCES users(id) ON DELETE SET NULL,
  contact_phone    VARCHAR(20),
  status           person_status NOT NULL DEFAULT 'missing',
  is_approved      BOOLEAN DEFAULT FALSE,
  approved_by      UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_at      TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at       TIMESTAMPTZ DEFAULT now(),
  found_at         TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_missing_status ON missing_persons(status);
CREATE INDEX IF NOT EXISTS idx_missing_approved ON missing_persons(is_approved);

-- ------------------------------------------------------------------
-- WANTED PERSONS
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wanted_persons (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_code       VARCHAR(20),
  name            VARCHAR(150) NOT NULL,
  age             INTEGER,
  gender          VARCHAR(20),
  photo_url       TEXT,
  crime_description TEXT,
  danger_level    VARCHAR(20) DEFAULT 'low',
  status          person_status NOT NULL DEFAULT 'wanted',
  created_at      TIMESTAMPTZ DEFAULT now(),
  captured_at     TIMESTAMPTZ
);

-- ------------------------------------------------------------------
-- SIGHTINGS (of missing / wanted persons)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sightings (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  missing_person_id UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
  wanted_person_id  UUID REFERENCES wanted_persons(id) ON DELETE CASCADE,
  reporter_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  address_text      VARCHAR(300),
  description       TEXT,
  photo_url         TEXT,
  seen_at           TIMESTAMPTZ DEFAULT now(),
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sightings_missing ON sightings(missing_person_id);
CREATE INDEX IF NOT EXISTS idx_sightings_wanted ON sightings(wanted_person_id);

-- ------------------------------------------------------------------
-- ANNOUNCEMENTS
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS announcements (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        VARCHAR(200) NOT NULL,
  body         TEXT NOT NULL,
  category     announcement_type NOT NULL DEFAULT 'news',
  language     VARCHAR(10) DEFAULT 'en',
  region       VARCHAR(100),
  sub_city     VARCHAR(100),
  author_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  is_published BOOLEAN DEFAULT TRUE,
  published_at TIMESTAMPTZ DEFAULT now(),
  created_at   TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_announcements_published ON announcements(published_at);

-- ------------------------------------------------------------------
-- ANNOUNCEMENT TRANSLATIONS
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS announcement_translations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  language        VARCHAR(10) NOT NULL,
  title           VARCHAR(200) NOT NULL,
  body            TEXT NOT NULL,
  source          VARCHAR(20) DEFAULT 'auto',
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (announcement_id, language)
);
CREATE INDEX IF NOT EXISTS idx_at_announcement ON announcement_translations(announcement_id);

-- ------------------------------------------------------------------
-- LEGAL CONTENT (laws & rights information)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS legal_content (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         VARCHAR(200) NOT NULL,
  body          TEXT NOT NULL,
  category      VARCHAR(80),
  language      VARCHAR(10) DEFAULT 'en',
  is_published  BOOLEAN DEFAULT TRUE,
  review_status VARCHAR(20) NOT NULL DEFAULT 'published',
  reviewed_by   UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- ------------------------------------------------------------------
-- LEGAL CONTENT REVIEW HISTORY (UC-16 / SD-9)
-- ------------------------------------------------------------------
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

-- ------------------------------------------------------------------
-- POLICE STATIONS (nearest-station lookup for People of Determination)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS police_stations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       VARCHAR(150) NOT NULL,
  phone      VARCHAR(20),
  region     VARCHAR(100),
  sub_city   VARCHAR(100),
  latitude   DOUBLE PRECISION,
  longitude  DOUBLE PRECISION,
  is_active  BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stations_region ON police_stations(region, sub_city);

-- ------------------------------------------------------------------
-- DIRECT CALL REQUESTS (People of Determination - UC-4)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS direct_call_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  citizen_phone TEXT,
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  station_id    UUID REFERENCES police_stations(id) ON DELETE SET NULL,
  station_name  VARCHAR(150),
  station_phone VARCHAR(20),
  status        VARCHAR(20) NOT NULL DEFAULT 'requested',
  handled_by    UUID REFERENCES users(id) ON DELETE SET NULL,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  completed_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_direct_call_user ON direct_call_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_direct_call_status ON direct_call_requests(status);

-- ------------------------------------------------------------------
-- SIGN LANGUAGE MESSAGES (People of Determination - UC-5)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sign_language_messages (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID REFERENCES users(id) ON DELETE SET NULL,
  report_id UUID REFERENCES reports(id) ON DELETE SET NULL,
  video_url TEXT NOT NULL,
  note      TEXT,
  latitude  DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  status    VARCHAR(20) NOT NULL DEFAULT 'submitted',
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sign_lang_user ON sign_language_messages(user_id);

-- ------------------------------------------------------------------
-- SOCIAL SHARE ANALYTICS (UC-11)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS share_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
  content_type VARCHAR(40) NOT NULL,
  content_id   UUID,
  platform     VARCHAR(40) NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_share_events_created ON share_events(created_at);

-- ------------------------------------------------------------------
-- GEOFENCES
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS geofences (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(150) NOT NULL,
  type        VARCHAR(50) NOT NULL DEFAULT 'zone',
  region      VARCHAR(100),
  sub_city    VARCHAR(100),
  woreda      VARCHAR(100),
  center_lat  DOUBLE PRECISION,
  center_lng  DOUBLE PRECISION,
  radius_m    DOUBLE PRECISION,
  polygon     JSONB DEFAULT '[]'::jsonb,
  sensitivity VARCHAR(20) DEFAULT 'medium',
  is_active   BOOLEAN DEFAULT TRUE,
  created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_geofences_owner ON geofences(created_by);

-- ------------------------------------------------------------------
-- CONVERSATIONS & MESSAGES (real-time chat)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type       conversation_type NOT NULL DEFAULT 'direct',
  title      VARCHAR(200),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at       TIMESTAMPTZ DEFAULT now(),
  last_read_at    TIMESTAMPTZ,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  body            TEXT,
  message_type    message_type NOT NULL DEFAULT 'text',
  attachment_url  TEXT,
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  created_at      TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at);

-- ------------------------------------------------------------------
-- CHAT RATINGS (post-conversation satisfaction)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_ratings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment         TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (conversation_id, user_id)
);

-- ------------------------------------------------------------------
-- AUDIT LOG
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  action      VARCHAR(120) NOT NULL,
  entity      VARCHAR(80),
  entity_id   UUID,
  detail      JSONB DEFAULT '{}'::jsonb,
  ip_address  VARCHAR(45),
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at);

-- ------------------------------------------------------------------
-- DISPATCH ASSIGNMENTS (SOS / reports to police units)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dispatch_assignments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sos_id        UUID REFERENCES sos_alerts(id) ON DELETE CASCADE,
  report_id     UUID REFERENCES reports(id) ON DELETE CASCADE,
  assigned_to   UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_by   UUID REFERENCES users(id) ON DELETE SET NULL,
  status        VARCHAR(40) NOT NULL DEFAULT 'assigned',
  notes         TEXT,
  distance_m    DOUBLE PRECISION,
  eta_seconds   INTEGER,
  created_at    TIMESTAMPTZ DEFAULT now(),
  completed_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_dispatch_sos ON dispatch_assignments(sos_id);

-- ------------------------------------------------------------------
-- REPORT FEEDBACK / SATISFACTION RATINGS
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS report_feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_feedback_report ON report_feedback(report_id);

-- ------------------------------------------------------------------
-- CALLBACK REQUESTS (officer -> citizen follow-up scheduling)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS callback_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id      UUID REFERENCES reports(id) ON DELETE CASCADE,
  citizen_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  officer_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  requested_slot TIMESTAMPTZ,
  mode           VARCHAR(20) NOT NULL DEFAULT 'voice',
  status         VARCHAR(20) NOT NULL DEFAULT 'pending',
  notes          TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  responded_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_callbacks_citizen ON callback_requests(citizen_id);
CREATE INDEX IF NOT EXISTS idx_callbacks_officer ON callback_requests(officer_id);

-- ------------------------------------------------------------------
-- NOTIFICATIONS (Figure 24 / Doc 4.8.2)
-- ------------------------------------------------------------------
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

-- ------------------------------------------------------------------
-- SYSTEM CONFIG (Figure 19 Class Diagram / Figure 24)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_config (
  id            SERIAL PRIMARY KEY,
  setting_name  VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  last_modified TIMESTAMPTZ DEFAULT now()
);

-- ------------------------------------------------------------------
-- UPDATED_AT TRIGGERS
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated ON users;
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_reports_updated ON reports;
CREATE TRIGGER trg_reports_updated BEFORE UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_at_updated ON announcement_translations;
CREATE TRIGGER trg_at_updated BEFORE UPDATE ON announcement_translations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
