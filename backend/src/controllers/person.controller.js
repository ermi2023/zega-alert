import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { encrypt, decrypt } from '../utils/crypto.js';

// contact_phone is PII and stored AES-256-GCM encrypted at rest.
const decryptRow = (row) => (row ? { ...row, contact_phone: decrypt(row.contact_phone) } : row);

export const createMissing = async (req, res) => {
  const { name, age, gender, photo_url, description, last_seen_lat, last_seen_lng, last_seen_address, last_seen_at, contact_phone } = req.body;
  if (!name) return fail(res, 'name is required');
  // Citizen submissions are queued for Regional Admin authorization; staff entries are auto-approved.
  const autoApprove = req.user.role !== 'citizen';
  const { rows } = await query(
    `INSERT INTO missing_persons (name, age, gender, photo_url, description, last_seen_lat, last_seen_lng,
       last_seen_address, last_seen_at, reporter_id, contact_phone, is_approved, approved_by, approved_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING *`,
    [name, age || null, gender || null, photo_url || null, description || null,
      last_seen_lat || null, last_seen_lng || null, last_seen_address || null,
      last_seen_at || null, req.user.id, encrypt(contact_phone || req.user.phone),
      autoApprove, autoApprove ? req.user.id : null, autoApprove ? new Date() : null],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'create_missing_person','missing_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), autoApprove ? 'Missing person registered' : 'Missing person submitted for approval', 201);
};

export const listMissing = async (req, res) => {
  const { status, approval } = req.query;
  const where = [];
  const params = [];
  if (status) { params.push(status); where.push(`status = $${params.length}`); }
  const isStaff = req.user && req.user.role !== 'citizen';
  if (!isStaff) {
    params.push(req.user.id);
    where.push(`(is_approved = true OR reporter_id = $${params.length})`);
  } else if (approval === 'pending') {
    where.push(`is_approved = false AND rejection_reason IS NULL`);
  } else if (approval === 'approved') {
    where.push(`is_approved = true`);
  } else if (approval === 'rejected') {
    where.push(`rejection_reason IS NOT NULL`);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await query(`SELECT * FROM missing_persons ${whereSql} ORDER BY created_at DESC`, params);
  ok(res, rows.map(decryptRow));
};

export const getMissing = async (req, res) => {
  const { rows } = await query('SELECT * FROM missing_persons WHERE id = $1', [req.params.id]);
  const row = rows[0];
  if (!row) return fail(res, 'Not found', 404);
  const isStaff = req.user && req.user.role !== 'citizen';
  if (!isStaff && !row.is_approved && row.reporter_id !== req.user.id) return fail(res, 'Not found', 404);
  ok(res, decryptRow(row));
};

export const approveMissing = async (req, res) => {
  const { rows } = await query(
    `UPDATE missing_persons SET is_approved = true, approved_by = $1, approved_at = now(), rejection_reason = NULL
     WHERE id = $2 RETURNING *`,
    [req.user.id, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'approve_missing_person','missing_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Missing person approved and published');
};

export const rejectMissing = async (req, res) => {
  const { reason } = req.body;
  const { rows } = await query(
    `UPDATE missing_persons SET is_approved = false, approved_by = $1, approved_at = now(), rejection_reason = $2
     WHERE id = $3 RETURNING *`,
    [req.user.id, reason || 'Rejected by regional administrator', req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'reject_missing_person','missing_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Missing person rejected');
};

export const updateMissing = async (req, res) => {
  const { status, found_at } = req.body;
  if (!['missing', 'found'].includes(status)) return fail(res, 'status must be missing|found');
  const { rows } = await query(
    `UPDATE missing_persons SET status = $1, found_at = CASE WHEN $1='found' THEN COALESCE($2, now()) ELSE NULL END WHERE id = $3 RETURNING *`,
    [status, found_at || null, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  ok(res, decryptRow(rows[0]), 'Updated');
};

export const createSighting = async (req, res) => {
  const { missing_person_id, wanted_person_id, latitude, longitude, address_text, description, photo_url, seen_at } = req.body;
  if (!latitude || !longitude) return fail(res, 'latitude and longitude are required');
  if (!missing_person_id && !wanted_person_id) return fail(res, 'missing_person_id or wanted_person_id required');
  const { rows } = await query(
    `INSERT INTO sightings (missing_person_id, wanted_person_id, reporter_id, latitude, longitude, address_text, description, photo_url, seen_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [missing_person_id || null, wanted_person_id || null, req.user.id, latitude, longitude,
      address_text || null, description || null, photo_url || null, seen_at || null],
  );
  ok(res, rows[0], 'Sighting reported', 201);
};

export const listSightings = async (req, res) => {
  const { missing_person_id, wanted_person_id } = req.query;
  let rows;
  if (missing_person_id) rows = (await query('SELECT * FROM sightings WHERE missing_person_id = $1 ORDER BY seen_at DESC', [missing_person_id])).rows;
  else if (wanted_person_id) rows = (await query('SELECT * FROM sightings WHERE wanted_person_id = $1 ORDER BY seen_at DESC', [wanted_person_id])).rows;
  else rows = (await query('SELECT * FROM sightings ORDER BY seen_at DESC')).rows;
  ok(res, rows);
};

export const createWanted = async (req, res) => {
  const { name, age, gender, photo_url, crime_description, danger_level } = req.body;
  if (!name) return fail(res, 'name is required');
  const { rows } = await query(
    `INSERT INTO wanted_persons (name, age, gender, photo_url, crime_description, danger_level)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [name, age || null, gender || null, photo_url || null, crime_description || null, danger_level || 'low'],
  );
  ok(res, rows[0], 'Wanted person registered', 201);
};

export const listWanted = async (req, res) => {
  const { status } = req.query;
  const rows = status
    ? (await query('SELECT * FROM wanted_persons WHERE status = $1 ORDER BY created_at DESC', [status])).rows
    : (await query('SELECT * FROM wanted_persons ORDER BY created_at DESC')).rows;
  ok(res, rows);
};

export const updateWanted = async (req, res) => {
  const { status } = req.body;
  if (!['wanted', 'captured'].includes(status)) return fail(res, 'status must be wanted|captured');
  const { rows } = await query(
    `UPDATE wanted_persons SET status = $1, captured_at = CASE WHEN $1='captured' THEN now() ELSE NULL END WHERE id = $2 RETURNING *`,
    [status, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  ok(res, rows[0], 'Updated');
};
