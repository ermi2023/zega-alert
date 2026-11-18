import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

const MAX_CITIZEN_GEOFENCES = 10;
const SENSITIVITIES = ['low', 'medium', 'high'];
const TYPES = ['zone', 'school', 'police_station', 'hospital', 'event', 'residence', 'market'];

const audit = (userId, action, id, detail) => query(
  `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,$2,'geofences',$3,$4)`,
  [userId, action, id, JSON.stringify(detail || {})],
).catch(() => {});

export const listGeofences = async (req, res) => {
  const { region, type, active } = req.query;
  const params = [];
  const where = [];
  if (region) { params.push(region); where.push(`region = $${params.length}`); }
  if (type) { params.push(type); where.push(`type = $${params.length}`); }
  if (active === 'true') { where.push('is_active = true'); }
  if (active === 'false') { where.push('is_active = false'); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await query(`SELECT * FROM geofences ${whereSql} ORDER BY created_at DESC`, params);
  ok(res, rows);
};

export const createGeofence = async (req, res) => {
  const { name, label, type, region, sub_city, woreda, center_lat, center_lng, radius_m, polygon, sensitivity } = req.body;
  if (!name) return fail(res, 'name is required');
  if (type && !TYPES.includes(type)) return fail(res, `type must be one of ${TYPES.join(', ')}`);
  if (sensitivity && !SENSITIVITIES.includes(sensitivity)) {
    return fail(res, `sensitivity must be one of ${SENSITIVITIES.join(', ')}`);
  }
  if (center_lat != null && center_lng == null) return fail(res, 'center_lng is required with center_lat');
  if (center_lng != null && center_lat == null) return fail(res, 'center_lat is required with center_lng');

  // NFR: each citizen may define at most 10 active safety zones (doc 4.3.4).
  if (req.user.role === 'citizen') {
    const count = await query(
      'SELECT COUNT(*)::int AS n FROM geofences WHERE created_by = $1 AND is_active = true',
      [req.user.id],
    );
    if (count.rows[0].n >= MAX_CITIZEN_GEOFENCES) {
      return fail(res, `You can define at most ${MAX_CITIZEN_GEOFENCES} active safety zones`, 409);
    }
  }

  const { rows } = await query(
    `INSERT INTO geofences (name, label, type, region, sub_city, woreda, center_lat, center_lng, radius_m, polygon, sensitivity, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
    [name, label || name, type || 'zone', region || null, sub_city || null, woreda || null,
      center_lat ?? null, center_lng ?? null, radius_m || null,
      polygon ? JSON.stringify(polygon) : '[]', sensitivity || 'medium', req.user.id],
  );
  await audit(req.user.id, 'create_geofence', rows[0].id, { name, type: type || 'zone', sensitivity });
  ok(res, rows[0], 'Geofence created', 201);
};

export const updateGeofence = async (req, res) => {
  const existing = await query('SELECT * FROM geofences WHERE id = $1', [req.params.id]);
  if (!existing.rows[0]) return fail(res, 'Not found', 404);
  const isAdmin = ['system_admin', 'regional_admin', 'dispatcher'].includes(req.user.role);
  if (!isAdmin && existing.rows[0].created_by !== req.user.id) {
    return fail(res, 'Forbidden: not your geofence', 403);
  }
  const {
    name, label, type, region, sub_city, woreda, center_lat, center_lng,
    radius_m, polygon, sensitivity, is_active,
  } = req.body;
  if (sensitivity && !SENSITIVITIES.includes(sensitivity)) {
    return fail(res, `sensitivity must be one of ${SENSITIVITIES.join(', ')}`);
  }
  if (type && !TYPES.includes(type)) return fail(res, `type must be one of ${TYPES.join(', ')}`);
  const { rows } = await query(
    `UPDATE geofences SET
       name = COALESCE($1, name),
       label = COALESCE($2, label),
       type = COALESCE($3, type),
       region = COALESCE($4, region),
       sub_city = COALESCE($5, sub_city),
       woreda = COALESCE($6, woreda),
       center_lat = COALESCE($7, center_lat),
       center_lng = COALESCE($8, center_lng),
       radius_m = COALESCE($9, radius_m),
       polygon = COALESCE($10, polygon),
       sensitivity = COALESCE($11, sensitivity),
       is_active = COALESCE($12, is_active)
     WHERE id = $13 RETURNING *`,
    [name || null, label || null, type || null, region || null, sub_city || null, woreda || null,
      center_lat ?? null, center_lng ?? null, radius_m ?? null,
      polygon != null ? JSON.stringify(polygon) : null, sensitivity || null, is_active ?? null,
      req.params.id],
  );
  await audit(req.user.id, 'update_geofence', req.params.id, {
    name: name || existing.rows[0].name, sensitivity: sensitivity || existing.rows[0].sensitivity,
    is_active: is_active ?? existing.rows[0].is_active,
  });
  ok(res, rows[0], 'Geofence updated');
};

export const deleteGeofence = async (req, res) => {
  const existing = await query('SELECT * FROM geofences WHERE id = $1', [req.params.id]);
  if (!existing.rows[0]) return fail(res, 'Not found', 404);
  const isAdmin = ['system_admin', 'regional_admin'].includes(req.user.role);
  if (!isAdmin && existing.rows[0].created_by !== req.user.id) {
    return fail(res, 'Forbidden: not your geofence', 403);
  }
  await query('DELETE FROM geofences WHERE id = $1', [req.params.id]);
  await audit(req.user.id, 'delete_geofence', req.params.id, { name: existing.rows[0].name });
  ok(res, null, 'Deleted');
};
