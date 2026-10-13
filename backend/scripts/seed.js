import { pool } from '../src/config/db.js';
import { hashPassword } from '../src/utils/password.js';

const PASSWORD = 'password123';

const upsertUser = async (u) => {
  const password_hash = await hashPassword(PASSWORD);
  const { rows } = await pool.query(
    `INSERT INTO users (full_name, phone, email, password_hash, role, region, sub_city, woreda, is_verified, is_active)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,true)
     ON CONFLICT (phone) DO UPDATE SET email = EXCLUDED.email, role = EXCLUDED.role
     RETURNING id`,
    [u.full_name, u.phone, u.email, password_hash, u.role, u.region, u.sub_city, u.woreda],
  );
  return rows[0].id;
};

const users = [
  { full_name: 'System Admin', phone: '0911000001', email: 'admin@zega.et', role: 'system_admin', region: null, sub_city: null, woreda: null },
  { full_name: 'Ermias Taddesse', phone: '0911000002', email: 'regional.admin@zega.et', role: 'regional_admin', region: 'Amhara', sub_city: 'Debark', woreda: '01' },
  { full_name: 'Dispatcher Liya', phone: '0911000003', email: 'dispatcher@zega.et', role: 'dispatcher', region: 'Amhara', sub_city: 'Debark', woreda: '01' },
  { full_name: 'Officer Alemu', phone: '0911000004', email: 'police@zega.et', role: 'police', region: 'Amhara', sub_city: 'Debark', woreda: '01' },
  { full_name: 'Sara Mohammed', phone: '0911000005', email: 'citizen1@zega.et', role: 'citizen', region: 'Amhara', sub_city: 'Debark', woreda: '01' },
  { full_name: 'Abebe Kebede', phone: '0911000006', email: 'citizen2@zega.et', role: 'citizen', region: 'Amhara', sub_city: 'Gondar', woreda: '02' },
];

const announcements = [
  { title: 'Weekly safety briefing', body: 'The regional command holds a public safety briefing every Monday at 4pm. Attendees are welcome.', category: 'news', region: 'Amhara', sub_city: 'Debark' },
  { title: 'Heavy rain warning', body: 'Flash flooding possible in low-lying areas. Avoid crossing rivers until further notice.', category: 'warning', region: 'Amhara', sub_city: 'Debark' },
  { title: 'Report crimes anonymously', body: 'Citizens can now submit anonymous crime reports from the app. Your identity is protected.', category: 'legal', region: null, sub_city: null },
];

const legal = [
  { title: 'Your rights when reporting a crime', body: 'Every citizen has the right to report a crime and to be treated with dignity. You may remain anonymous.', category: 'rights', language: 'en' },
  { title: 'ክርክር ሪፖርት የማድረግ መብቶች', body: 'ማንኛውም ዜጋ ወንጀል የመዘገብ እና በክብር የመታየት መብት አለው።', category: 'rights', language: 'am' },
];

const geofences = [
  { name: 'Debark University Campus', type: 'school', region: 'Amhara', sub_city: 'Debark', center_lat: 13.1355, center_lng: 37.8975, radius_m: 800, polygon: [] },
  { name: 'Debark Central Police Station', type: 'police_station', region: 'Amhara', sub_city: 'Debark', center_lat: 13.1408, center_lng: 37.8977, radius_m: 200, polygon: [] },
  { name: 'Debark General Hospital', type: 'hospital', region: 'Amhara', sub_city: 'Debark', center_lat: 13.1372, center_lng: 37.8991, radius_m: 300, polygon: [] },
];

const run = async () => {
  const ids = {};
  for (const u of users) ids[u.email] = await upsertUser(u);

  for (const a of announcements) {
    await pool.query(
      `INSERT INTO announcements (title, body, category, region, sub_city, author_id)
       VALUES ($1,$2,$3,$4,$5,$6)`,
      [a.title, a.body, a.category, a.region, a.sub_city, ids['admin@zega.et']],
    );
  }

  for (const l of legal) {
    await pool.query(
      'INSERT INTO legal_content (title, body, category, language) VALUES ($1,$2,$3,$4)',
      [l.title, l.body, l.category, l.language],
    );
  }

  for (const g of geofences) {
    await pool.query(
      `INSERT INTO geofences (name, type, region, sub_city, center_lat, center_lng, radius_m, polygon)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [g.name, g.type, g.region, g.sub_city, g.center_lat, g.center_lng, g.radius_m, JSON.stringify(g.polygon)],
    );
  }

  await pool.query(
    `INSERT INTO reports (reporter_id, category, severity, status, title, description, latitude, longitude, address_text, region, sub_city, woreda, is_anonymous, priority_score, assigned_to)
     VALUES ($1,'theft','high','under_review','Phone snatched near campus gate','A student had her phone stolen at 6pm near the east gate.',13.1352,37.8980,'Debark University east gate','Amhara','Debark','01',false,70,$2)`,
    [ids['citizen1@zega.et'], ids['police@zega.et']],
  );
  await pool.query(
    `INSERT INTO reports (reporter_id, category, severity, status, title, description, latitude, longitude, address_text, region, sub_city, woreda, is_anonymous, priority_score)
     VALUES ($1,'suspicious_activity','medium','pending','Suspicious van on main road','White van parked near the market for two hours, unknown people looking around.',13.1410,37.8985,'Main market road','Amhara','Debark','01',true,40)`,
    [ids['citizen2@zega.et']],
  );

  const missingId = (await pool.query(
    `INSERT INTO missing_persons (name, age, gender, description, last_seen_lat, last_seen_lng, last_seen_address, reporter_id, contact_phone, status)
     VALUES ('Kidist Ayele',22,'female','Last seen wearing a blue jacket and carrying a backpack.',13.1338,37.8992,'Near the bus station',$1,'0911000005','missing') RETURNING id`,
    [ids['citizen1@zega.et']],
  )).rows[0].id;

  await pool.query(
    `INSERT INTO wanted_persons (name, age, gender, crime_description, danger_level, status)
     VALUES ('Daniel Worku',34,'male','Armed robbery and theft in the Debark area.', 'high', 'wanted')`,
  );

  await pool.query(
    `INSERT INTO sightings (missing_person_id, reporter_id, latitude, longitude, address_text, description)
     VALUES ($1,$2,13.1440,37.9005,'Debark market','A person matching her description was seen near the fruit stalls.')`,
    [missingId, ids['citizen2@zega.et']],
  );

  await pool.query(
    `INSERT INTO sos_alerts (user_id, latitude, longitude, address_text, description, region, sub_city, woreda, status, dispatcher_id, resolved_at)
     VALUES ($1,13.1355,37.8975,'Dormitory 3','Accident near dormitory, need medical help.','Amhara','Debark','01','resolved',$2, now())`,
    [ids['citizen1@zega.et'], ids['dispatcher@zega.et']],
  );

  const convo = (await pool.query(
    "INSERT INTO conversations (type, title) VALUES ('direct','Police support chat') RETURNING id",
  )).rows[0].id;
  await pool.query(
    'INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1,$2),($1,$3)',
    [convo, ids['citizen1@zega.et'], ids['police@zega.et']],
  );
  await pool.query(
    `INSERT INTO messages (conversation_id, sender_id, body) VALUES ($1,$2,'Hello, I need help with my report status.'),($1,$3,'Hi Sara, your report is under review. We will update you soon.')`,
    [convo, ids['citizen1@zega.et'], ids['police@zega.et']],
  );

  console.log('[SEED] Demo data inserted. Login password for all users: password123');
};

try {
  await run();
} catch (e) {
  console.error('[SEED] Failed:', e.message);
  process.exit(1);
} finally {
  await pool.end();
}
