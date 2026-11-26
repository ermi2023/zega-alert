-- ============================================================
-- ZEGA-ALERT Seed Data
-- Demo users, announcements, legal content, geofences, reports,
-- missing/wanted persons, sightings, SOS, chat, feedback, callbacks
-- ============================================================

-- NOTE: This SQL seed file uses gen_random_uuid() which requires pgcrypto.
-- It is designed to run AFTER schema.sql.
--
-- For a richer seed experience, use: npm run db:seed (which runs scripts/seed.js)

-- ------------------------------------------------------------------
-- USERS (password for all: password123, bcrypt hash)
-- NOTE: `ON CONFLICT DO NOTHING` (without a column list) is intentional.
-- The users table has TWO separate unique constraints — users_phone_key
-- AND users_email_key. Specifying only `ON CONFLICT (phone)` (as the
-- original did) catches phone conflicts but throws
-- `duplicate key value violates users_email_key` when an existing row
-- shares an email but not a phone — which aborted the whole seed run.
-- The bare form catches either conflict.
-- ------------------------------------------------------------------
INSERT INTO users (full_name, phone, email, password_hash, role, region, sub_city, woreda, is_verified, is_active) VALUES
  ('System Admin',   '0911000001', 'admin@zega.et',         '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'system_admin',    NULL, NULL, NULL, true, true),
  ('Ermias Taddesse','0911000002', 'regional.admin@zega.et','$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'regional_admin',  'Amhara', 'Debark', '01', true, true),
  ('Dispatcher Liya','0911000003', 'dispatcher@zega.et',    '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'dispatcher',      'Amhara', 'Debark', '01', true, true),
  ('Officer Alemu',  '0911000004', 'police@zega.et',        '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'police',          'Amhara', 'Debark', '01', true, true),
  ('Sara Mohammed',  '0911000005', 'citizen1@zega.et',      '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'citizen',         'Amhara', 'Debark', '01', true, true),
  ('Abebe Kebede',   '0911000006', 'citizen2@zega.et',      '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'citizen',         'Amhara', 'Gondar', '02', true, true)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------
-- ANNOUNCEMENTS
-- announcements has only a PK on id (uuid), so the original
-- `ON CONFLICT DO NOTHING` was a no-op that inserted a fresh copy of
-- each demo announcement on every deploy. Guard with WHERE NOT EXISTS
-- on title instead. Note: the author user 0911000001 doesn't currently
-- exist in this DB (so the SELECT returns nothing today), but the
-- guard makes the idempotency explicit so the duplicates never resume
-- if the user is later added.
-- ------------------------------------------------------------------
INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
SELECT 'Weekly safety briefing', 'The regional command holds a public safety briefing every Monday at 4pm. Attendees are welcome.', 'news', 'en', 'Amhara', 'Debark', id FROM users WHERE phone = '0911000001'
  AND NOT EXISTS (SELECT 1 FROM announcements a WHERE a.title = 'Weekly safety briefing');

-- Sample announcement translations
INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'am', 'ሳብታዊ የደህንነት መደበኛ ስብሰባ', 'ክልላዊ ባለሥልጣኑ በየሰኞ ሰዓት 4:00 ላይ የሕዝብ ደህንነት መደበኛ ስብሰባ ያደርጋል። ሰዎች መግባት ይችላሉ።', 'manual'
FROM announcements a WHERE a.title = 'Weekly safety briefing'
  AND NOT EXISTS (SELECT 1 FROM announcement_translations t WHERE t.announcement_id = a.id AND t.language = 'am');

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'om', 'Gabaa Nageenyyaa Torbeessaa', 'Kumaataa Leenjii karaa nageenyyaa haftii Guyyamaa 4:00 irraa jecha. Qabatanii lammataa jirtan.', 'manual'
FROM announcements a WHERE a.title = 'Weekly safety briefing'
  AND NOT EXISTS (SELECT 1 FROM announcement_translations t WHERE t.announcement_id = a.id AND t.language = 'om');

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'ti', 'ምልዕተ ውግእ ሰሙን', 'ካብ ውሽጢ ክልል ባለሥልጣን ብ kulli ሰኞ ከምውትር ሰዓት 4:00 ዝበለ ዘረባ ይግባ። ሰባት ይክኣሉ።', 'manual'
FROM announcements a WHERE a.title = 'Weekly safety briefing'
  AND NOT EXISTS (SELECT 1 FROM announcement_translations t WHERE t.announcement_id = a.id AND t.language = 'ti');

INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
SELECT 'Heavy rain warning', 'Flash flooding possible in low-lying areas. Avoid crossing rivers until further notice.', 'warning', 'en', 'Amhara', 'Debark', id FROM users WHERE phone = '0911000001'
  AND NOT EXISTS (SELECT 1 FROM announcements a WHERE a.title = 'Heavy rain warning');

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'am', 'የዝናብ ማጥላቂያ', 'በዝቅተኛ ቦታዎች ውስጥ የንንም ጎርፍ ሊኖር ይችላል። ምንም በአስቸኳይ ሁኔታ ወንዞችን አልፉ።', 'manual'
FROM announcements a WHERE a.title = 'Heavy rain warning'
  AND NOT EXISTS (SELECT 1 FROM announcement_translations t WHERE t.announcement_id = a.id AND t.language = 'am');

INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
SELECT 'Report crimes anonymously', 'Citizens can now submit anonymous crime reports from the app. Your identity is protected.', 'legal', 'en', NULL, NULL, id FROM users WHERE phone = '0911000001'
  AND NOT EXISTS (SELECT 1 FROM announcements a WHERE a.title = 'Report crimes anonymously');

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'am', 'ወንጀል በማይታወቅ ሁኔታ ያስታውሱ', 'ዜጎች አሁን ከመተግበሪያው በማይታወቅ ሁኔታ የወንጀል ሪፖርት ማስገባት ይችላሉ። ማንነትዎ የተጠበቀ ነው።', 'manual'
FROM announcements a WHERE a.title = 'Report crimes anonymously'
  AND NOT EXISTS (SELECT 1 FROM announcement_translations t WHERE t.announcement_id = a.id AND t.language = 'am');

-- ------------------------------------------------------------------
-- LEGAL CONTENT
-- No natural-key unique constraint exists, so ON CONFLICT DO NOTHING is a
-- no-op (the only constraint is the PK on id, which is a fresh uuid every
-- time). Guard with WHERE NOT EXISTS instead so each demo article is
-- inserted exactly once across deploys.
-- ------------------------------------------------------------------
INSERT INTO legal_content (title, body, category, language)
SELECT v.title, v.body, v.category, v.language
FROM (VALUES
  ('Your rights when reporting a crime', 'Every citizen has the right to report a crime and to be treated with dignity. You may remain anonymous.', 'rights', 'en'),
  ('ክርክር ሪፖርት የማድረግ መብቶች', 'ማንኛውም ዜጋ ወንጀል የመዘገብ እና በክብር የመታየት መብት አለው።', 'rights', 'am')
) AS v(title, body, category, language)
WHERE NOT EXISTS (SELECT 1 FROM legal_content l WHERE l.title = v.title);

-- ------------------------------------------------------------------
-- GEOFENCES
-- Same situation as legal_content: only a PK on id, no natural-key
-- uniqueness. Guard by name so each demo geofence is inserted once.
-- ------------------------------------------------------------------
INSERT INTO geofences (name, type, region, sub_city, center_lat, center_lng, radius_m, polygon)
SELECT v.name, v.type, v.region, v.sub_city, v.center_lat, v.center_lng, v.radius_m, '[]'::jsonb
FROM (VALUES
  ('Debark University Campus',  'school',          'Amhara', 'Debark', 13.1355, 37.8975, 800),
  ('Debark Central Police Station', 'police_station', 'Amhara', 'Debark', 13.1408, 37.8977, 200),
  ('Debark General Hospital',   'hospital',        'Amhara', 'Debark', 13.1372, 37.8991, 300)
) AS v(name, type, region, sub_city, center_lat, center_lng, radius_m)
WHERE NOT EXISTS (SELECT 1 FROM geofences g WHERE g.name = v.name);

-- ------------------------------------------------------------------
-- REPORTS
-- Each report is seeded exactly once. We guard on the (title, address)
-- pair because reports have no unique constraint and the seed runs on
-- every deploy (npm run start:deploy calls deploy-migrate which runs
-- seed.sql). Without these guards every deploy added a fresh copy of
-- every demo row — by 2026-11 the table held ~38x the expected rows.
-- ------------------------------------------------------------------
INSERT INTO reports (reporter_id, category, severity, status, title, description, latitude, longitude, address_text, region, sub_city, woreda, is_anonymous, priority_score, assigned_to)
SELECT citizen.id, 'theft', 'high', 'under_review', 'Phone snatched near campus gate',
  'A student had her phone stolen at 6pm near the east gate.', 13.1352, 37.8980,
  'Debark University east gate', 'Amhara', 'Debark', '01', false, 70, police.id
FROM users citizen, users police
WHERE citizen.phone = '0911000005' AND police.phone = '0911000004'
  AND NOT EXISTS (SELECT 1 FROM reports r WHERE r.title = 'Phone snatched near campus gate' AND r.address_text = 'Debark University east gate')
LIMIT 1;

INSERT INTO reports (reporter_id, category, severity, status, title, description, latitude, longitude, address_text, region, sub_city, woreda, is_anonymous, priority_score)
SELECT id, 'suspicious_activity', 'medium', 'pending', 'Suspicious van on main road',
  'White van parked near the market for two hours, unknown people looking around.', 13.1410, 37.8985,
  'Main market road', 'Amhara', 'Debark', '01', true, 40
FROM users WHERE phone = '0911000006'
  AND NOT EXISTS (SELECT 1 FROM reports r WHERE r.title = 'Suspicious van on main road' AND r.address_text = 'Main market road');

-- ------------------------------------------------------------------
-- MISSING PERSONS (seed once, by name + last_seen_address)
-- ------------------------------------------------------------------
INSERT INTO missing_persons (name, age, gender, description, last_seen_lat, last_seen_lng, last_seen_address, reporter_id, contact_phone, status)
SELECT 'Kidist Ayele', 22, 'female', 'Last seen wearing a blue jacket and carrying a backpack.',
  13.1338, 37.8992, 'Near the bus station', id, '0911000005', 'missing'
FROM users WHERE phone = '0911000005'
  AND NOT EXISTS (SELECT 1 FROM missing_persons m WHERE m.name = 'Kidist Ayele' AND m.last_seen_address = 'Near the bus station');

-- ------------------------------------------------------------------
-- WANTED PERSONS (seed once, by name + crime_description)
-- ------------------------------------------------------------------
INSERT INTO wanted_persons (name, age, gender, crime_description, danger_level, status)
SELECT 'Daniel Worku', 34, 'male', 'Armed robbery and theft in the Debark area.', 'high', 'wanted'
WHERE NOT EXISTS (SELECT 1 FROM wanted_persons w WHERE w.name = 'Daniel Worku' AND w.crime_description = 'Armed robbery and theft in the Debark area.');

-- ------------------------------------------------------------------
-- SIGHTINGS (seed once, per missing-person + description pair)
-- ------------------------------------------------------------------
INSERT INTO sightings (missing_person_id, reporter_id, latitude, longitude, address_text, description)
SELECT mp.id, u.id, 13.1440, 37.9005, 'Debark market',
  'A person matching her description was seen near the fruit stalls.'
FROM missing_persons mp, users u
WHERE mp.name = 'Kidist Ayele' AND u.phone = '0911000006'
  AND NOT EXISTS (
    SELECT 1 FROM sightings s
    WHERE s.missing_person_id = mp.id AND s.description = 'A person matching her description was seen near the fruit stalls.'
  );

-- ------------------------------------------------------------------
-- SOS ALERTS (seed once, per user + address + description)
-- ------------------------------------------------------------------
INSERT INTO sos_alerts (user_id, latitude, longitude, address_text, description, region, sub_city, woreda, status, dispatcher_id, resolved_at)
SELECT citizen.id, 13.1355, 37.8975, 'Dormitory 3', 'Accident near dormitory, need medical help.',
  'Amhara', 'Debark', '01', 'resolved', dispatcher.id, now()
FROM users citizen, users dispatcher
WHERE citizen.phone = '0911000005' AND dispatcher.phone = '0911000003'
  AND NOT EXISTS (SELECT 1 FROM sos_alerts s WHERE s.user_id = citizen.id AND s.address_text = 'Dormitory 3' AND s.description = 'Accident near dormitory, need medical help.');

-- ------------------------------------------------------------------
-- CONVERSATIONS & MESSAGES
-- The conversation row itself is guarded by title. Messages are guarded
-- by (conversation_id, body) so the same seed message is never inserted
-- twice even though messages has no unique constraint.
-- ------------------------------------------------------------------
INSERT INTO conversations (type, title)
SELECT 'direct', 'Police support chat'
WHERE NOT EXISTS (SELECT 1 FROM conversations c WHERE c.title = 'Police support chat');

INSERT INTO conversation_participants (conversation_id, user_id)
SELECT c.id, u.id FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000005'
  AND NOT EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = c.id AND user_id = u.id);

INSERT INTO conversation_participants (conversation_id, user_id)
SELECT c.id, u.id FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000004'
  AND NOT EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = c.id AND user_id = u.id);

INSERT INTO messages (conversation_id, sender_id, body)
SELECT c.id, u.id, 'Hello, I need help with my report status.'
FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000005'
  AND NOT EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = c.id AND m.body = 'Hello, I need help with my report status.');

INSERT INTO messages (conversation_id, sender_id, body)
SELECT c.id, u.id, 'Hi Sara, your report is under review. We will update you soon.'
FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000004'
  AND NOT EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = c.id AND m.body = 'Hi Sara, your report is under review. We will update you soon.');

-- ------------------------------------------------------------------
-- POLICE STATIONS (nearest-station lookup for People of Determination)
-- Already idempotent — guarded by name via NOT EXISTS.
-- ------------------------------------------------------------------
INSERT INTO police_stations (name, address_text, phone, region, sub_city, latitude, longitude)
SELECT v.name, v.address_text, v.phone, v.region, v.sub_city, v.latitude, v.longitude
FROM (VALUES
  ('Debark Central Police Station', 'Debark, Amhara', '0911000004', 'Amhara', 'Debark', 13.1408, 37.8977),
  ('Addis Ababa Central Police Station', 'Arada, Addis Ababa', '0911000002', 'Addis Ababa', 'Arada', 9.0355, 38.7490),
  ('Dire Dawa Police Station', 'Addis Ketema, Dire Dawa', '0911000003', 'Dire Dawa', 'Addis Ketema', 9.5931, 41.8661),
  ('Hawassa City Police Station', 'Hawassa, Sidama', '0911000005', 'Sidama', 'Hawassa', 7.0620, 38.4763)
) AS v(name, address_text, phone, region, sub_city, latitude, longitude)
WHERE NOT EXISTS (SELECT 1 FROM police_stations s WHERE s.name = v.name);

UPDATE police_stations
SET address_text = concat_ws(', ', NULLIF(BTRIM(sub_city), ''), NULLIF(BTRIM(region), ''))
WHERE BTRIM(address_text) = ''
  AND (NULLIF(BTRIM(sub_city), '') IS NOT NULL OR NULLIF(BTRIM(region), '') IS NOT NULL);

INSERT INTO police_station_users (station_id, user_id)
SELECT s.id, u.id
FROM police_stations s
JOIN users u ON u.phone = s.phone AND u.role = 'police'
ON CONFLICT DO NOTHING;

SELECT 'Seed data inserted successfully. Login password for all users: password123' AS result;
