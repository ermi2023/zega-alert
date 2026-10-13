import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

const MAX_CITIZEN_GEOFENCES = 10;
const SENSITIVITIES = ['low', 'medium', 'high'];

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
  const { name, type, region, sub_city, woreda, center_lat, center_lng, radius_m, polygon, sensitivity } = req.body;
  if (!name) return fail(res, 'name is required');

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
    `INSERT INTO geofences (name, type, region, sub_city, woreda, center_lat, center_lng, radius_m, polygon, sensitivity, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
    [name, req.user.role === 'citizen' ? 'zone' : (type || 'zone'), region || null, sub_city || null, woreda || null,
      center_lat || null, center_lng || null, radius_m || null,
      polygon ? JSON.stringify(polygon) : '[]', sensitivity || 'medium', req.user.id],
  );
  ok(res, rows[0], 'Geofence created', 201);
};

export const updateGeofence = async (req, res) => {
  const existing = await query('SELECT * FROM geofences WHERE id = $1', [req.params.id]);
  if (!existing.rows[0]) return fail(res, 'Not found', 404);
  const isAdmin = ['system_admin', 'regional_admin', 'dispatcher'].includes(req.user.role);
  if (!isAdmin && existing.rows[0].created_by !== req.user.id) {
    return fail(res, 'Forbidden: not your geofence', 403);
  }
  const { name, sensitivity, is_active, radius_m } = req.body;
  if (sensitivity && !SENSITIVITIES.includes(sensitivity)) {
    return fail(res, `sensitivity must be one of ${SENSITIVITIES.join(', ')}`);
  }
  const { rows } = await query(
    `UPDATE geofences SET name = COALESCE($1, name), sensitivity = COALESCE($2, sensitivity),
       is_active = COALESCE($3, is_active), radius_m = COALESCE($4, radius_m)
     WHERE id = $5 RETURNING *`,
    [name || null, sensitivity || null, is_active ?? null, radius_m || null, req.params.id],
  );
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
  ok(res, null, 'Deleted');
};
