-- cleanup_seed_duplicates.sql
-- Run ONCE to remove the demo-seed duplicates that accumulated because the
-- pre-fix seed.sql inserted a fresh copy of every demo row on every deploy.
--
-- Strategy: for each seeded table, keep only the OLDEST row matching each demo
-- natural key (title, name+address, etc.), delete the rest. Real user-entered
-- rows — which don't match any demo key — are left untouched because the
-- WHERE clause only targets rows that DO match a demo key.
--
-- Usage (from backend/):
--   node scripts/run-sql.js ../src/db/cleanup_seed_duplicates.sql
-- or directly with psql:
--   psql "$DATABASE_URL" -f src/db/cleanup_seed_duplicates.sql

BEGIN;

-- messages: keep oldest per (conversation_id, body) pair among demo messages
-- (MIN(uuid) isn't a built-in aggregate, so cast to text then back to uuid.)
DELETE FROM messages m
WHERE m.body IN (
    'Hello, I need help with my report status.',
    'Hi Sara, your report is under review. We will update you soon.'
  )
  AND m.id NOT IN (
    SELECT MIN(id::text)::uuid FROM messages
    WHERE body IN (
      'Hello, I need help with my report status.',
      'Hi Sara, your report is under review. We will update you soon.'
    )
    GROUP BY conversation_id, body
  );

-- conversation_participants: composite PK (conversation_id, user_id), no `id`
-- column. Use ctid (the physical row address) to keep exactly one row per
-- (conversation_id, user_id) pair within the demo chat — the OLDEST row,
-- to match the keep-oldest strategy used for the other tables.
DELETE FROM conversation_participants cp
USING conversation_participants cp2
WHERE cp.conversation_id IN (SELECT id FROM conversations WHERE title = 'Police support chat')
  AND cp2.conversation_id = cp.conversation_id
  AND cp2.user_id = cp.user_id
  AND cp.ctid > cp2.ctid;  -- keep the older (smaller ctid), delete the newer duplicates

-- conversations: keep one 'Police support chat'
DELETE FROM conversations c
WHERE c.title = 'Police support chat'
  AND c.id NOT IN (SELECT MIN(id::text)::uuid FROM conversations WHERE title = 'Police support chat');

-- sos_alerts: keep oldest per (user_id, address_text, description) for the demo SOS
DELETE FROM sos_alerts s
WHERE s.address_text = 'Dormitory 3'
  AND s.description = 'Accident near dormitory, need medical help.'
  AND s.id NOT IN (
    SELECT MIN(id::text)::uuid FROM sos_alerts
    WHERE address_text = 'Dormitory 3' AND description = 'Accident near dormitory, need medical help.'
    GROUP BY user_id, address_text, description
  );

-- sightings: keep oldest per (missing_person_id, description) for the demo sighting
DELETE FROM sightings s
WHERE s.description = 'A person matching her description was seen near the fruit stalls.'
  AND s.id NOT IN (
    SELECT MIN(id::text)::uuid FROM sightings
    WHERE description = 'A person matching her description was seen near the fruit stalls.'
    GROUP BY missing_person_id, description
  );

-- wanted_persons: keep oldest 'Daniel Worku' with the demo crime_description
DELETE FROM wanted_persons w
WHERE w.name = 'Daniel Worku'
  AND w.crime_description = 'Armed robbery and theft in the Debark area.'
  AND w.id NOT IN (
    SELECT MIN(id::text)::uuid FROM wanted_persons
    WHERE name = 'Daniel Worku' AND crime_description = 'Armed robbery and theft in the Debark area.'
  );

-- missing_persons: keep oldest 'Kidist Ayele' near the bus station
DELETE FROM missing_persons m
WHERE m.name = 'Kidist Ayele'
  AND m.last_seen_address = 'Near the bus station'
  AND m.id NOT IN (
    SELECT MIN(id::text)::uuid FROM missing_persons
    WHERE name = 'Kidist Ayele' AND last_seen_address = 'Near the bus station'
  );

-- reports: keep oldest per (title, address_text) for the two demo reports
DELETE FROM reports r
WHERE (r.title, r.address_text) IN (
    ('Phone snatched near campus gate', 'Debark University east gate'),
    ('Suspicious van on main road', 'Main market road')
  )
  AND r.id NOT IN (
    SELECT MIN(id::text)::uuid FROM reports
    WHERE (title, address_text) IN (
      ('Phone snatched near campus gate', 'Debark University east gate'),
      ('Suspicious van on main road', 'Main market road')
    )
    GROUP BY title, address_text
  );

-- announcements: keep oldest per title for the three demo announcements
DELETE FROM announcements a
WHERE a.title IN ('Weekly safety briefing','Heavy rain warning','Report crimes anonymously')
  AND a.id NOT IN (
    SELECT MIN(id::text)::uuid FROM announcements
    WHERE title IN ('Weekly safety briefing','Heavy rain warning','Report crimes anonymously')
    GROUP BY title
  );

-- legal_content: keep oldest per title for the two demo articles
DELETE FROM legal_content l
WHERE l.title IN ('Your rights when reporting a crime','ክርክር ሪፖርት የማድረግ መብቶች')
  AND l.id NOT IN (
    SELECT MIN(id::text)::uuid FROM legal_content
    WHERE title IN ('Your rights when reporting a crime','ክርክር ሪፖርት የማድረግ መብቶች')
    GROUP BY title
  );

-- geofences: keep oldest per name for the three demo geofences
DELETE FROM geofences g
WHERE g.name IN ('Debark University Campus','Debark Central Police Station','Debark General Hospital')
  AND g.id NOT IN (
    SELECT MIN(id::text)::uuid FROM geofences
    WHERE name IN ('Debark University Campus','Debark Central Police Station','Debark General Hospital')
    GROUP BY name
  );

COMMIT;

-- Optional summary (does not modify data)
SELECT 'reports' AS table_name, COUNT(*)::text AS remaining FROM reports
UNION ALL SELECT 'missing_persons', COUNT(*)::text FROM missing_persons
UNION ALL SELECT 'wanted_persons', COUNT(*)::text FROM wanted_persons
UNION ALL SELECT 'sightings', COUNT(*)::text FROM sightings
UNION ALL SELECT 'sos_alerts', COUNT(*)::text FROM sos_alerts
UNION ALL SELECT 'conversations', COUNT(*)::text FROM conversations
UNION ALL SELECT 'conversation_participants', COUNT(*)::text FROM conversation_participants
UNION ALL SELECT 'messages', COUNT(*)::text FROM messages
UNION ALL SELECT 'police_stations', COUNT(*)::text FROM police_stations
UNION ALL SELECT 'announcements', COUNT(*)::text FROM announcements
UNION ALL SELECT 'legal_content', COUNT(*)::text FROM legal_content
UNION ALL SELECT 'geofences', COUNT(*)::text FROM geofences;
