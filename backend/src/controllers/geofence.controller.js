import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { notifyGeofenceChange } from '../services/geofence-notify.service.js';

const MANAGER_ROLES = ['system_admin', 'regional_admin', 'dispatcher'];
const TYPES = ['zone', 'school', 'police_station', 'hospital', 'event', 'residence', 'market'];

const validCoordinate = (value, min, max) => value != null && value !== ''
  && Number.isFinite(Number(value)) && Number(value) >= min && Number(value) <= max;
const validPolygon = (polygon) => Array.isArray(polygon) && polygon.length >= 3 && polygon.every((point) => {
  const lat = Array.isArray(point) ? point[0] : point?.lat ?? point?.latitude;
  const lng = Array.isArray(point) ? point[1] : point?.lng ?? point?.longitude;
  return validCoordinate(lat, -90, 90) && validCoordinate(lng, -180, 180);
});
const validShape = ({ center_lat, center_lng, radius_m, polygon }) => {
  if (polygon != null && !Array.isArray(polygon)) return false;
  if (Array.isArray(polygon) && polygon.length > 0) return validPolygon(polygon);
  return validCoordinate(center_lat, -90, 90)
    && validCoordinate(center_lng, -180, 180)
    && Number.isFinite(Number(radius_m))
    && Number(radius_m) >= 50;
};

const audit = (userId, action, id, detail) => query(
  `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,$2,'geofences',$3,$4)`,
  [userId, action, id, JSON.stringify(detail || {})],
).catch(() => {});

const notifyResidents = async (geofence, event) => {
  try {
    const result = await notifyGeofenceChange(geofence, event);
    if (result.notifiedCount > 0) {
      console.log(`[GEOFENCE] Created ${event} notice for ${result.notifiedCount} residents`);
    }
  } catch (error) {
    console.error('[GEOFENCE NOTIFICATION ERROR]', error.message);
  }
};

export const listGeofences = async (req, res) => {
  const { region, type, active } = req.query;
  const params = [];
  const where = [`(g.created_by IS NULL OR EXISTS (
    SELECT 1 FROM users creator
    WHERE creator.id = g.created_by
      AND creator.role IN ('police', 'dispatcher', 'regional_admin', 'system_admin')
  ))`];
  if (!MANAGER_ROLES.includes(req.user.role)) where.push('g.is_active = true');
  if (region) { params.push(region); where.push(`g.region = $${params.length}`); }
  if (type) { params.push(type); where.push(`g.type = $${params.length}`); }
  if (active === 'true') { where.push('g.is_active = true'); }
  if (active === 'false' && MANAGER_ROLES.includes(req.user.role)) { where.push('g.is_active = false'); }
  const { rows } = await query(
    `SELECT g.* FROM geofences g WHERE ${where.join(' AND ')} ORDER BY g.created_at DESC`,
    params,
  );
  ok(res, rows);
};

export const createGeofence = async (req, res) => {
  if (!MANAGER_ROLES.includes(req.user.role)) return fail(res, 'Only authorized staff can publish safety zones', 403);
  const { name, label, type, region, sub_city, woreda, center_lat, center_lng, radius_m, polygon } = req.body;
  if (!name) return fail(res, 'name is required');
  if (type && !TYPES.includes(type)) return fail(res, `type must be one of ${TYPES.join(', ')}`);
  if (center_lat != null && center_lng == null) return fail(res, 'center_lng is required with center_lat');
  if (center_lng != null && center_lat == null) return fail(res, 'center_lat is required with center_lng');
  if (!validShape({ center_lat, center_lng, radius_m, polygon })) {
    return fail(res, 'Provide a valid center and radius of at least 50 meters, or a boundary with at least three valid points');
  }

  const { rows } = await query(
    `INSERT INTO geofences (name, label, type, region, sub_city, woreda, center_lat, center_lng, radius_m, polygon, sensitivity, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
    [name, label || name, type || 'zone', region || null, sub_city || null, woreda || null,
      center_lat ?? null, center_lng ?? null, radius_m ?? null,
      polygon ? JSON.stringify(polygon) : '[]', 'medium', req.user.id],
  );
  await audit(req.user.id, 'create_geofence', rows[0].id, { name, type: type || 'zone' });
  if (rows[0].is_active) await notifyResidents(rows[0], 'published');
  ok(res, rows[0], 'Geofence created', 201);
};

export const updateGeofence = async (req, res) => {
  if (!MANAGER_ROLES.includes(req.user.role)) return fail(res, 'Only authorized staff can manage safety zones', 403);
  const existing = await query('SELECT * FROM geofences WHERE id = $1', [req.params.id]);
  if (!existing.rows[0]) return fail(res, 'Not found', 404);
  const previous = existing.rows[0];
  const {
    name, label, type, region, sub_city, woreda, center_lat, center_lng,
    radius_m, polygon, is_active,
  } = req.body;
  if (type && !TYPES.includes(type)) return fail(res, `type must be one of ${TYPES.join(', ')}`);
  const shape = { ...existing.rows[0], ...req.body };
  if (!validShape(shape)) {
    return fail(res, 'Provide a valid center and radius of at least 50 meters, or a boundary with at least three valid points');
  }
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
       is_active = COALESCE($11, is_active)
     WHERE id = $12 RETURNING *`,
    [name || null, label || null, type || null, region || null, sub_city || null, woreda || null,
      center_lat ?? null, center_lng ?? null, radius_m ?? null,
      polygon != null ? JSON.stringify(polygon) : null, is_active ?? null,
      req.params.id],
  );
  await audit(req.user.id, 'update_geofence', req.params.id, {
    name: name || existing.rows[0].name,
    is_active: is_active ?? existing.rows[0].is_active,
  });
  const notificationFields = [
    'name', 'label', 'type', 'region', 'sub_city', 'woreda',
    'center_lat', 'center_lng', 'radius_m', 'polygon', 'is_active',
  ];
  const notificationChanged = notificationFields.some((field) =>
    req.body[field] !== undefined
      && JSON.stringify(req.body[field]) !== JSON.stringify(previous[field]));
  if (notificationChanged && (previous.is_active || rows[0].is_active)) {
    const event = rows[0].is_active
      ? previous.is_active ? 'updated' : 'published'
      : 'deactivated';
    await notifyResidents(rows[0], event);
  }
  ok(res, rows[0], 'Geofence updated');
};

export const deleteGeofence = async (req, res) => {
  if (!['system_admin', 'regional_admin'].includes(req.user.role)) {
    return fail(res, 'Only an administrator can delete a safety zone', 403);
  }
  const existing = await query('SELECT * FROM geofences WHERE id = $1', [req.params.id]);
  if (!existing.rows[0]) return fail(res, 'Not found', 404);
  await query('DELETE FROM geofences WHERE id = $1', [req.params.id]);
  await audit(req.user.id, 'delete_geofence', req.params.id, { name: existing.rows[0].name });
  if (existing.rows[0].is_active) await notifyResidents(existing.rows[0], 'removed');
  ok(res, null, 'Deleted');
};
