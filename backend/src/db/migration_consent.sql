-- P3: consent/ToS tracking
ALTER TABLE users ADD COLUMN IF NOT EXISTS accepted_terms_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS accepted_privacy_at TIMESTAMPTZ;
