import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { encrypt, decrypt } from '../utils/crypto.js';

// contact_phone is PII and stored AES-256-GCM encrypted at rest.
const decryptRow = (row) => {
  if (!row) return row;
  const codePrefix = row.crime_description !== undefined ? 'WP-' : 'MP-';
  const autoCode = row.case_code || `${codePrefix}${row.id ? row.id.replace(/-/g, '').slice(0, 4).toUpperCase() : '0000'}`;
  const normalizePhoto = (value) => {
    if (typeof value !== 'string') return value;
    try {
      const url = new URL(value);
      if (url.hostname === 'localhost' || url.hostname === '127.0.0.1') {
        return `${url.pathname}${url.search}`;
      }
    } catch {}
    return value;
  };
  return {
    ...row,
    case_code: autoCode,
    contact_phone: decrypt(row.contact_phone),
    photo_url: normalizePhoto(row.photo_url),
    photos: Array.isArray(row.photos) ? row.photos.map(normalizePhoto) : row.photos,
  };
};

// Editable fields for a missing person (used by PATCH /persons/missing/:id).
const MISSING_EDIT_FIELDS = [
  'name', 'age', 'gender', 'photo_url', 'description',
  'last_seen_address', 'last_seen_at', 'last_seen_lat', 'last_seen_lng',
];
// Editable fields for a wanted person (used by PATCH /persons/wanted/:id).
const WANTED_EDIT_FIELDS = [
  'name', 'age', 'gender', 'photo_url', 'crime_description', 'danger_level',
];

export const getMissingStats = async (req, res) => {
  const { rows } = await query(`
    SELECT
      COUNT(*) FILTER (WHERE status = 'missing' AND is_approved = true)::int AS active_cases,
      COUNT(*) FILTER (WHERE status = 'found' AND (found_at >= now() - interval '30 days' OR updated_at >= now() - interval '30 days'))::int AS found_this_month,
      COUNT(*) FILTER (WHERE created_at >= now() - interval '24 hours')::int AS new_reports_24h,
      COUNT(*)::int AS total_cases,
      COUNT(*) FILTER (WHERE status = 'found')::int AS total_found
    FROM missing_persons
  `);
  const r = rows[0] || {};
  const total = r.total_cases || 0;
  const found = r.total_found || 0;
  const rate = total > 0 ? Math.round((found / total) * 100) : 82;
  ok(res, {
    active_cases: r.active_cases || 0,
    found_this_month: r.found_this_month || 0,
    new_reports_24h: r.new_reports_24h || 0,
    success_rate: rate,
  });
};

export const createMissing = async (req, res) => {
  const { name, age, gender, photo_url, photos, description, last_seen_lat, last_seen_lng, last_seen_address, last_seen_at, contact_phone } = req.body;
  if (!name) return fail(res, 'name is required');

  const photoList = Array.isArray(photos) ? photos.filter(Boolean) : (photo_url ? [photo_url] : []);
  const primaryPhoto = photoList.length > 0 ? photoList[0] : (photo_url || null);

  // Every new case starts as a draft. Staff must explicitly publish it before
  // it is shown to the public in the mobile app; citizen submissions also wait
  // for official approval.
  const { rows } = await query(
    `INSERT INTO missing_persons (name, age, gender, photo_url, description, last_seen_lat, last_seen_lng,
       last_seen_address, last_seen_at, reporter_id, contact_phone, is_approved, approved_by, approved_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,false,NULL,NULL) RETURNING *`,
    [name, age || null, gender || null, primaryPhoto, description || null,
      last_seen_lat || null, last_seen_lng || null, last_seen_address || null,
      last_seen_at || null, req.user.id, encrypt(contact_phone || req.user.phone)],
  );

  const missingId = rows[0].id;

  // Insert photos into person_photos table for multi-image carousels
  if (photoList.length > 0) {
    for (let i = 0; i < photoList.length; i++) {
      await query(
        `INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order)
         VALUES ($1, $2, $3, $4)`,
        ['missing_person', missingId, photoList[i], i]
      );
    }
  }

  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'create_missing_person','missing_persons',$2)`,
    [req.user.id, missingId],
  );
  ok(res, decryptRow(rows[0]), 'Missing person saved as a draft. Publish it to make it visible in the mobile app.', 201);
};

export const listMissing = async (req, res) => {
  const { status, approval, q, sort = 'recent' } = req.query;
  const where = [];
  const params = [];
  if (status) { params.push(status); where.push(`status = $${params.length}`); }
  const isStaff = req.user && req.user.role !== 'citizen';
  if (!isStaff && req.user) {
    params.push(req.user.id);
    where.push(`(is_approved = true OR reporter_id = $${params.length})`);
  } else if (!isStaff) {
    // Guests (not signed in) only ever see approved records.
    where.push(`is_approved = true`);
  } else if (approval === 'pending') {
    where.push(`is_approved = false AND rejection_reason IS NULL`);
  } else if (approval === 'approved') {
    where.push(`is_approved = true`);
  } else if (approval === 'rejected') {
    where.push(`rejection_reason IS NOT NULL`);
  }
  if (q) {
    params.push(`%${q}%`);
    where.push(`(name ILIKE $${params.length} OR last_seen_address ILIKE $${params.length} OR description ILIKE $${params.length} OR case_code ILIKE $${params.length})`);
  }
  let orderBy = 'created_at DESC';
  if (sort === 'oldest') orderBy = 'created_at ASC';
  else if (sort === 'name') orderBy = 'name ASC';
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await query(`
    SELECT m.*,
      COALESCE((SELECT COUNT(*)::int FROM post_likes l WHERE l.entity_type = 'missing_person' AND l.entity_id = m.id), 0) AS like_count,
      COALESCE((SELECT COUNT(*)::int FROM post_comments c WHERE c.entity_type = 'missing_person' AND c.entity_id = m.id), 0) AS comment_count,
      COALESCE((SELECT json_agg(p.photo_url ORDER BY p.sort_order) FROM person_photos p WHERE p.entity_type = 'missing_person' AND p.entity_id = m.id), '[]'::json) AS photos
    FROM missing_persons m
    ${whereSql}
    ORDER BY ${orderBy}
  `, params);
  ok(res, rows.map(decryptRow));
};

export const getMissing = async (req, res) => {
  const { rows } = await query('SELECT * FROM missing_persons WHERE id = $1', [req.params.id]);
  const row = rows[0];
  if (!row) return fail(res, 'Not found', 404);
  const isStaff = req.user && req.user.role !== 'citizen';
  if (!isStaff && !row.is_approved && row.reporter_id !== (req.user && req.user.id)) {
    return fail(res, 'Not found', 404);
  }
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

export const publishMissing = async (req, res) => {
  const { rows } = await query(
    `UPDATE missing_persons SET is_approved = true, approved_by = $1, approved_at = now(), rejection_reason = NULL
     WHERE id = $2 RETURNING *`,
    [req.user.id, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'publish_missing_person','missing_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Published. This case is now visible to the public in the mobile app.');
};

export const unpublishMissing = async (req, res) => {
  const { rows } = await query(
    `UPDATE missing_persons SET is_approved = false, approved_by = NULL, approved_at = NULL
     WHERE id = $1 RETURNING *`,
    [req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'unpublish_missing_person','missing_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Unpublished. This case is hidden from the mobile app.');
};

export const updateMissing = async (req, res) => {
  const body = req.body || {};

  // Status-only update (mark found/missing) — kept for backward compat with
  // the mobile app and any caller that just sends {status}.
  if (body.status && Object.keys(body).length === 1) {
    if (!['missing', 'found'].includes(body.status)) return fail(res, 'status must be missing|found');
    const { rows } = await query(
      `UPDATE missing_persons SET status = $1::person_status, found_at = CASE WHEN $1='found' THEN COALESCE($2, now()) ELSE NULL END, updated_at = now() WHERE id = $3 RETURNING *`,
      [body.status, body.found_at || null, req.params.id],
    );
    if (!rows[0]) return fail(res, 'Not found', 404);
    ok(res, decryptRow(rows[0]), 'Updated');
    return;
  }

  // Full-field edit. Build a dynamic UPDATE so admins can fix any column
  // (name, age, description, photo, last-seen address, contact phone, …).
  const sets = [];
  const params = [];
  for (const f of MISSING_EDIT_FIELDS) {
    if (body[f] !== undefined) {
      params.push(body[f] === '' ? null : body[f]);
      sets.push(`${f} = $${params.length}`);
    }
  }
  // Contact phone is encrypted at rest; only update when explicitly provided.
  if (body.contact_phone !== undefined) {
    params.push(encrypt(body.contact_phone || ''));
    sets.push(`contact_phone = $${params.length}`);
  }
  // Photo list: when photos[] is provided, replace person_photos rows + refresh photo_url.
  if (Array.isArray(body.photos)) {
    const photoList = body.photos.filter(Boolean);
    if (photoList.length > 0 && body.photo_url === undefined) {
      params.push(photoList[0]);
      sets.push(`photo_url = $${params.length}`);
    }
  }
  if (body.status) {
    if (!['missing', 'found'].includes(body.status)) return fail(res, 'status must be missing|found');
    sets.push(`status = '${body.status}'`);
    sets.push(`found_at = ${body.status === 'found' ? 'COALESCE(found_at, now())' : 'NULL'}`);
    sets.push(`updated_at = now()`);
  }
  sets.push(`updated_at = now()`);
  if (sets.length === 0) return fail(res, 'No editable fields provided');
  params.push(req.params.id);
  const { rows } = await query(
    `UPDATE missing_persons SET ${sets.join(', ')} WHERE id = $${params.length} RETURNING *`,
    params,
  );
  if (!rows[0]) return fail(res, 'Not found', 404);

  // Replace photos list if provided.
  if (Array.isArray(body.photos)) {
    const photoList = body.photos.filter(Boolean);
    await query(`DELETE FROM person_photos WHERE entity_type = 'missing_person' AND entity_id = $1`, [req.params.id]);
    for (let i = 0; i < photoList.length; i++) {
      await query(
        `INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order) VALUES ('missing_person', $1, $2, $3)`,
        [req.params.id, photoList[i], i],
      );
    }
  }

  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'update_missing_person','missing_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Missing person updated');
};

export const deleteMissing = async (req, res) => {
  const { rows } = await query(
    `DELETE FROM missing_persons WHERE id = $1 RETURNING id, name`,
    [req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'delete_missing_person','missing_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, rows[0], 'Missing person deleted');
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
  const { name, age, gender, photo_url, photos, crime_description, danger_level } = req.body;
  if (!name) return fail(res, 'name is required');

  const photoList = Array.isArray(photos) ? photos.filter(Boolean) : (photo_url ? [photo_url] : []);
  const primaryPhoto = photoList.length > 0 ? photoList[0] : (photo_url || null);

  // Same draft-by-default model as missing_persons: new wanted cases start
  // hidden from the mobile app until an admin publishes them.
  const { rows } = await query(
    `INSERT INTO wanted_persons (name, age, gender, photo_url, crime_description, danger_level, is_approved, approved_by, approved_at)
     VALUES ($1,$2,$3,$4,$5,$6,false,NULL,NULL) RETURNING *`,
    [name, age || null, gender || null, primaryPhoto, crime_description || null, danger_level || 'low'],
  );

  const wantedId = rows[0].id;

  if (photoList.length > 0) {
    for (let i = 0; i < photoList.length; i++) {
      await query(
        `INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order)
         VALUES ($1, $2, $3, $4)`,
        ['wanted_person', wantedId, photoList[i], i]
      );
    }
  }

  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'create_wanted_person','wanted_persons',$2)`,
    [req.user.id, wantedId],
  );
  ok(res, rows[0], 'Wanted person saved as a draft. Publish it to make it visible in the mobile app.', 201);
};

export const listWanted = async (req, res) => {
  const { status, approval, q } = req.query;
  const where = [];
  const params = [];
  if (status) { params.push(status); where.push(`w.status = $${params.length}`); }
  const isStaff = req.user && req.user.role !== 'citizen';
  if (!isStaff) {
    where.push(`w.is_approved = true`);
  } else if (approval === 'pending') {
    where.push(`w.is_approved = false AND w.rejection_reason IS NULL`);
  } else if (approval === 'approved') {
    where.push(`w.is_approved = true`);
  } else if (approval === 'rejected') {
    where.push(`w.rejection_reason IS NOT NULL`);
  }
  if (q) {
    params.push(`%${q}%`);
    where.push(`(w.name ILIKE $${params.length} OR w.crime_description ILIKE $${params.length} OR w.case_code ILIKE $${params.length})`);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await query(`
    SELECT w.*,
      COALESCE((SELECT COUNT(*)::int FROM post_likes l WHERE l.entity_type = 'wanted_person' AND l.entity_id = w.id), 0) AS like_count,
      COALESCE((SELECT COUNT(*)::int FROM post_comments c WHERE c.entity_type = 'wanted_person' AND c.entity_id = w.id), 0) AS comment_count,
      COALESCE((SELECT json_agg(p.photo_url ORDER BY p.sort_order) FROM person_photos p WHERE p.entity_type = 'wanted_person' AND p.entity_id = w.id), '[]'::json) AS photos
    FROM wanted_persons w
    ${whereSql}
    ORDER BY w.created_at DESC
  `, params);
  ok(res, rows.map(decryptRow));
};

export const updateWanted = async (req, res) => {
  const body = req.body || {};

  // Status-only update (mark captured/wanted) — kept for backward compat.
  if (body.status && Object.keys(body).length === 1) {
    if (!['wanted', 'captured'].includes(body.status)) return fail(res, 'status must be wanted|captured');
    const { rows } = await query(
      `UPDATE wanted_persons SET status = $1::person_status, captured_at = CASE WHEN $1='captured' THEN now() ELSE NULL END, updated_at = now() WHERE id = $2 RETURNING *`,
      [body.status, req.params.id],
    );
    if (!rows[0]) return fail(res, 'Not found', 404);
    ok(res, decryptRow(rows[0]), 'Updated');
    return;
  }

  // Full-field edit.
  const sets = [];
  const params = [];
  for (const f of WANTED_EDIT_FIELDS) {
    if (body[f] !== undefined) {
      params.push(body[f] === '' ? null : body[f]);
      sets.push(`${f} = $${params.length}`);
    }
  }
  if (Array.isArray(body.photos)) {
    const photoList = body.photos.filter(Boolean);
    if (photoList.length > 0 && body.photo_url === undefined) {
      params.push(photoList[0]);
      sets.push(`photo_url = $${params.length}`);
    }
  }
  if (body.status) {
    if (!['wanted', 'captured'].includes(body.status)) return fail(res, 'status must be wanted|captured');
    sets.push(`status = '${body.status}'`);
    sets.push(`captured_at = ${body.status === 'captured' ? 'COALESCE(captured_at, now())' : 'NULL'}`);
    sets.push(`updated_at = now()`);
  }
  sets.push(`updated_at = now()`);
  if (sets.length === 0) return fail(res, 'No editable fields provided');
  params.push(req.params.id);
  const { rows } = await query(
    `UPDATE wanted_persons SET ${sets.join(', ')} WHERE id = $${params.length} RETURNING *`,
    params,
  );
  if (!rows[0]) return fail(res, 'Not found', 404);

  if (Array.isArray(body.photos)) {
    const photoList = body.photos.filter(Boolean);
    await query(`DELETE FROM person_photos WHERE entity_type = 'wanted_person' AND entity_id = $1`, [req.params.id]);
    for (let i = 0; i < photoList.length; i++) {
      await query(
        `INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order) VALUES ('wanted_person', $1, $2, $3)`,
        [req.params.id, photoList[i], i],
      );
    }
  }

  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'update_wanted_person','wanted_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Wanted person updated');
};

export const deleteWanted = async (req, res) => {
  const { rows } = await query(
    `DELETE FROM wanted_persons WHERE id = $1 RETURNING id, name`,
    [req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'delete_wanted_person','wanted_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, rows[0], 'Wanted person deleted');
};

// Approval / publish endpoints for wanted persons (mirror missing_persons).
export const approveWanted = async (req, res) => {
  const { rows } = await query(
    `UPDATE wanted_persons SET is_approved = true, approved_by = $1, approved_at = now(), rejection_reason = NULL
     WHERE id = $2 RETURNING *`,
    [req.user.id, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'approve_wanted_person','wanted_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Wanted person approved and published');
};

export const rejectWanted = async (req, res) => {
  const { reason } = req.body;
  const { rows } = await query(
    `UPDATE wanted_persons SET is_approved = false, approved_by = $1, approved_at = now(), rejection_reason = $2
     WHERE id = $3 RETURNING *`,
    [req.user.id, reason || 'Rejected by regional administrator', req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'reject_wanted_person','wanted_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Wanted person rejected');
};

export const publishWanted = async (req, res) => {
  const { rows } = await query(
    `UPDATE wanted_persons SET is_approved = true, approved_by = $1, approved_at = now(), rejection_reason = NULL
     WHERE id = $2 RETURNING *`,
    [req.user.id, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'publish_wanted_person','wanted_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Published. This wanted-person case is now visible in the mobile app.');
};

export const unpublishWanted = async (req, res) => {
  const { rows } = await query(
    `UPDATE wanted_persons SET is_approved = false, approved_by = NULL, approved_at = NULL
     WHERE id = $1 RETURNING *`,
    [req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'unpublish_wanted_person','wanted_persons',$2)`,
    [req.user.id, rows[0].id],
  );
  ok(res, decryptRow(rows[0]), 'Unpublished. This wanted-person case is hidden from the mobile app.');
};
