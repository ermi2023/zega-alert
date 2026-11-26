ALTER TABLE police_stations
  ADD COLUMN IF NOT EXISTS address_text VARCHAR(300) NOT NULL DEFAULT '';

UPDATE police_stations
SET address_text = concat_ws(', ', NULLIF(BTRIM(sub_city), ''), NULLIF(BTRIM(region), ''))
WHERE BTRIM(address_text) = ''
  AND (NULLIF(BTRIM(sub_city), '') IS NOT NULL OR NULLIF(BTRIM(region), '') IS NOT NULL);

CREATE TABLE IF NOT EXISTS police_station_users (
  station_id UUID NOT NULL REFERENCES police_stations(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (station_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_police_station_users_user ON police_station_users(user_id);

ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS station_id UUID REFERENCES police_stations(id) ON DELETE SET NULL;
ALTER TABLE sos_alerts
  ADD COLUMN IF NOT EXISTS station_id UUID REFERENCES police_stations(id) ON DELETE SET NULL;
ALTER TABLE sign_language_messages
  ADD COLUMN IF NOT EXISTS station_id UUID REFERENCES police_stations(id) ON DELETE SET NULL;
ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS police_station_id UUID REFERENCES police_stations(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_reports_station ON reports(station_id);
CREATE INDEX IF NOT EXISTS idx_sos_station ON sos_alerts(station_id);
CREATE INDEX IF NOT EXISTS idx_sign_language_station ON sign_language_messages(station_id);
CREATE INDEX IF NOT EXISTS idx_conversations_station ON conversations(police_station_id);
