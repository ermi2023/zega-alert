ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_identity_verified BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS fan_verification_records (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name        TEXT,
  phone            TEXT,
  fan_number       VARCHAR(16) NOT NULL UNIQUE CHECK (fan_number ~ '^[0-9]{16}$'),
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_by       UUID REFERENCES users(id) ON DELETE SET NULL,
  verified_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  verified_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE fan_verification_records ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE fan_verification_records ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE fan_verification_records ALTER COLUMN fan_number TYPE VARCHAR(16);
ALTER TABLE fan_verification_records
  DROP CONSTRAINT IF EXISTS fan_verification_records_fan_number_check;
ALTER TABLE fan_verification_records
  DROP CONSTRAINT IF EXISTS fan_verification_records_fan_number_16_check;
UPDATE fan_verification_records
SET fan_number = lpad(fan_number, 16, '0')
WHERE length(fan_number) = 12 AND fan_number ~ '^[0-9]{12}$';
ALTER TABLE fan_verification_records
  ADD CONSTRAINT fan_verification_records_fan_number_16_check
  CHECK (fan_number ~ '^[0-9]{16}$');

CREATE INDEX IF NOT EXISTS idx_fan_verification_records_active
  ON fan_verification_records(fan_number) WHERE is_active = TRUE;

