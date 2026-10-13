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
-- ------------------------------------------------------------------
INSERT INTO users (full_name, phone, email, password_hash, role, region, sub_city, woreda, is_verified, is_active) VALUES
  ('System Admin',   '0911000001', 'admin@zega.et',         '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'system_admin',    NULL, NULL, NULL, true, true),
  ('Ermias Taddesse','0911000002', 'regional.admin@zega.et','$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'regional_admin',  'Amhara', 'Debark', '01', true, true),
  ('Dispatcher Liya','0911000003', 'dispatcher@zega.et',    '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'dispatcher',      'Amhara', 'Debark', '01', true, true),
  ('Officer Alemu',  '0911000004', 'police@zega.et',        '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'police',          'Amhara', 'Debark', '01', true, true),
  ('Sara Mohammed',  '0911000005', 'citizen1@zega.et',      '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'citizen',         'Amhara', 'Debark', '01', true, true),
  ('Abebe Kebede',   '0911000006', 'citizen2@zega.et',      '$2a$10$JivwlLc1olYaxkfqmY.TI.r5QDImd578F0aCdgI.iFbrH2Y0SE/ce', 'citizen',         'Amhara', 'Gondar', '02', true, true)
ON CONFLICT (phone) DO NOTHING;

-- ------------------------------------------------------------------
-- ANNOUNCEMENTS
-- ------------------------------------------------------------------
INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
SELECT 'Weekly safety briefing', 'The regional command holds a public safety briefing every Monday at 4pm. Attendees are welcome.', 'news', 'en', 'Amhara', 'Debark', id FROM users WHERE phone = '0911000001'
ON CONFLICT DO NOTHING;

-- Sample announcement translations
INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'am', 'ሳብታዊ የደህንነት መደበኛ ስብሰባ', 'ክልላዊ ባለሥልጣኑ በየሰኞ ሰዓት 4:00 ላይ የሕዝብ ደህንነት መደበኛ ስብሰባ ያደርጋል። ሰዎች መግባት ይችላሉ።', 'manual'
FROM announcements a WHERE a.title = 'Weekly safety briefing'
ON CONFLICT (announcement_id, language) DO NOTHING;

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'om', 'Gabaa Nageenyyaa Torbeessaa', 'Kumaataa Leenjii karaa nageenyyaa haftii Guyyamaa 4:00 irraa jecha. Qabatanii lammataa jirtan.', 'manual'
FROM announcements a WHERE a.title = 'Weekly safety briefing'
ON CONFLICT (announcement_id, language) DO NOTHING;

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'ti', 'ምልዕተ ውግእ ሰሙን', 'ካብ ውሽጢ ክልል ባለሥልጣን ብ kulli ሰኞ ከምውትር ሰዓት 4:00 ዝበለ ዘረባ ይግባ። ሰባት ይክኣሉ።', 'manual'
FROM announcements a WHERE a.title = 'Weekly safety briefing'
ON CONFLICT (announcement_id, language) DO NOTHING;

INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
SELECT 'Heavy rain warning', 'Flash flooding possible in low-lying areas. Avoid crossing rivers until further notice.', 'warning', 'en', 'Amhara', 'Debark', id FROM users WHERE phone = '0911000001'
ON CONFLICT DO NOTHING;

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'am', 'የዝናብ ማጥላቂያ', 'በዝቅተኛ ቦታዎች ውስጥ የንንም ጎርፍ ሊኖር ይችላል። ምንም በአስቸኳይ ሁኔታ ወንዞችን አልፉ።', 'manual'
FROM announcements a WHERE a.title = 'Heavy rain warning'
ON CONFLICT (announcement_id, language) DO NOTHING;

INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
SELECT 'Report crimes anonymously', 'Citizens can now submit anonymous crime reports from the app. Your identity is protected.', 'legal', 'en', NULL, NULL, id FROM users WHERE phone = '0911000001'
ON CONFLICT DO NOTHING;

INSERT INTO announcement_translations (announcement_id, language, title, body, source)
SELECT a.id, 'am', 'ወንጀል በማይታወቅ ሁኔታ ያስታውሱ', 'ዜጎች አሁን ከመተግበሪያው በማይታወቅ ሁኔታ የወንጀል ሪፖርት ማስገባት ይችላሉ። ማንነትዎ የተጠበቀ ነው።', 'manual'
FROM announcements a WHERE a.title = 'Report crimes anonymously'
ON CONFLICT (announcement_id, language) DO NOTHING;

-- ------------------------------------------------------------------
-- LEGAL CONTENT
-- ------------------------------------------------------------------
INSERT INTO legal_content (title, body, category, language) VALUES
  ('Your rights when reporting a crime', 'Every citizen has the right to report a crime and to be treated with dignity. You may remain anonymous.', 'rights', 'en'),
  ('ክርክር ሪፖርት የማድረግ መብቶች', 'ማንኛውም ዜጋ ወንጀል የመዘገብ እና በክብር የመታየት መብት አለው።', 'rights', 'am')
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------
-- GEOFENCES
-- ------------------------------------------------------------------
INSERT INTO geofences (name, type, region, sub_city, center_lat, center_lng, radius_m, polygon) VALUES
  ('Debark University Campus',  'school',          'Amhara', 'Debark', 13.1355, 37.8975, 800, '[]'::jsonb),
  ('Debark Central Police Station', 'police_station', 'Amhara', 'Debark', 13.1408, 37.8977, 200, '[]'::jsonb),
  ('Debark General Hospital',   'hospital',        'Amhara', 'Debark', 13.1372, 37.8991, 300, '[]'::jsonb)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------
-- REPORTS
-- ------------------------------------------------------------------
INSERT INTO reports (reporter_id, category, severity, status, title, description, latitude, longitude, address_text, region, sub_city, woreda, is_anonymous, priority_score, assigned_to)
SELECT citizen.id, 'theft', 'high', 'under_review', 'Phone snatched near campus gate',
  'A student had her phone stolen at 6pm near the east gate.', 13.1352, 37.8980,
  'Debark University east gate', 'Amhara', 'Debark', '01', false, 70, police.id
FROM users citizen, users police
WHERE citizen.phone = '0911000005' AND police.phone = '0911000004'
LIMIT 1;

INSERT INTO reports (reporter_id, category, severity, status, title, description, latitude, longitude, address_text, region, sub_city, woreda, is_anonymous, priority_score)
SELECT id, 'suspicious_activity', 'medium', 'pending', 'Suspicious van on main road',
  'White van parked near the market for two hours, unknown people looking around.', 13.1410, 37.8985,
  'Main market road', 'Amhara', 'Debark', '01', true, 40
FROM users WHERE phone = '0911000006';

-- ------------------------------------------------------------------
-- MISSING PERSONS
-- ------------------------------------------------------------------
INSERT INTO missing_persons (name, age, gender, description, last_seen_lat, last_seen_lng, last_seen_address, reporter_id, contact_phone, status)
SELECT 'Kidist Ayele', 22, 'female', 'Last seen wearing a blue jacket and carrying a backpack.',
  13.1338, 37.8992, 'Near the bus station', id, '0911000005', 'missing'
FROM users WHERE phone = '0911000005';

-- ------------------------------------------------------------------
-- WANTED PERSONS
-- ------------------------------------------------------------------
INSERT INTO wanted_persons (name, age, gender, crime_description, danger_level, status) VALUES
  ('Daniel Worku', 34, 'male', 'Armed robbery and theft in the Debark area.', 'high', 'wanted');

-- ------------------------------------------------------------------
-- SIGHTINGS
-- ------------------------------------------------------------------
INSERT INTO sightings (missing_person_id, reporter_id, latitude, longitude, address_text, description)
SELECT mp.id, u.id, 13.1440, 37.9005, 'Debark market',
  'A person matching her description was seen near the fruit stalls.'
FROM missing_persons mp, users u
WHERE mp.name = 'Kidist Ayele' AND u.phone = '0911000006';

-- ------------------------------------------------------------------
-- SOS ALERTS
-- ------------------------------------------------------------------
INSERT INTO sos_alerts (user_id, latitude, longitude, address_text, description, region, sub_city, woreda, status, dispatcher_id, resolved_at)
SELECT citizen.id, 13.1355, 37.8975, 'Dormitory 3', 'Accident near dormitory, need medical help.',
  'Amhara', 'Debark', '01', 'resolved', dispatcher.id, now()
FROM users citizen, users dispatcher
WHERE citizen.phone = '0911000005' AND dispatcher.phone = '0911000003';

-- ------------------------------------------------------------------
-- CONVERSATIONS & MESSAGES
-- ------------------------------------------------------------------
INSERT INTO conversations (type, title) VALUES ('direct', 'Police support chat');

INSERT INTO conversation_participants (conversation_id, user_id)
SELECT c.id, u.id FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000005'
  AND NOT EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = c.id AND user_id = u.id);

INSERT INTO conversation_participants (conversation_id, user_id)
SELECT c.id, u.id FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000004'
  AND NOT EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = c.id AND user_id = u.id);

INSERT INTO messages (conversation_id, sender_id, body)
SELECT c.id, u.id, 'Hello, I need help with my report status.'
FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000005';

INSERT INTO messages (conversation_id, sender_id, body)
SELECT c.id, u.id, 'Hi Sara, your report is under review. We will update you soon.'
FROM conversations c, users u WHERE c.title = 'Police support chat' AND u.phone = '0911000004';

-- ------------------------------------------------------------------
-- POLICE STATIONS (nearest-station lookup for People of Determination)
-- ------------------------------------------------------------------
INSERT INTO police_stations (name, phone, region, sub_city, latitude, longitude)
SELECT v.name, v.phone, v.region, v.sub_city, v.latitude, v.longitude
FROM (VALUES
  ('Debark Central Police Station', '0911000004', 'Amhara', 'Debark', 13.1408, 37.8977),
  ('Addis Ababa Central Police Station', '0911000002', 'Addis Ababa', 'Arada', 9.0355, 38.7490),
  ('Dire Dawa Police Station', '0911000003', 'Dire Dawa', 'Addis Ketema', 9.5931, 41.8661),
  ('Hawassa City Police Station', '0911000005', 'Sidama', 'Hawassa', 7.0620, 38.4763)
) AS v(name, phone, region, sub_city, latitude, longitude)
WHERE NOT EXISTS (SELECT 1 FROM police_stations s WHERE s.name = v.name);

SELECT 'Seed data inserted successfully. Login password for all users: password123' AS result;
