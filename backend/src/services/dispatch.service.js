import { query } from '../config/db.js';
import { getRecentPositions } from '../controllers/position.controller.js';

const EARTH_RADIUS_M = 6371000;
// Average urban police response speed assumed for ETA estimation (~40 km/h).
const ASSUMED_SPEED_MPS = 11.1;

export async function evaluateGeofenceContext(alert) {
  const context = { inside_safety_zone: false, nearest_police_station: null, nearest_zone: null };
  if (alert.latitude == null || alert.longitude == null) return context;

  const { rows: zones } = await query(
    `SELECT id, name, type, center_lat, center_lng, radius_m FROM geofences
     WHERE center_lat IS NOT NULL AND center_lng IS NOT NULL`,
  );
  if (!zones.length) return context;

  let best = null;
  for (const zone of zones) {
    const dist = haversine(alert.latitude, alert.longitude, zone.center_lat, zone.center_lng);
    const radius = zone.radius_m || 500;
    if (dist <= radius) {
      context.inside_safety_zone = true;
    }
    if (zone.type === 'police_station' && (!best || dist < best.dist)) {
      best = { id: zone.id, name: zone.name, dist };
    }
    if (!context.nearest_zone || dist < context.nearest_zone.dist) {
      context.nearest_zone = { id: zone.id, name: zone.name, type: zone.type, dist };
    }
  }
  if (best) context.nearest_police_station = best;
  return context;
}

export async function dispatchSos(alert) {
  const where = [];
  const params = [];
  where.push(`role IN ('police','dispatcher')`);
  where.push(`is_active = true`);
  if (alert.region) { params.push(alert.region); where.push(`region = $${params.length}`); }
  if (alert.sub_city) { params.push(alert.sub_city); where.push(`sub_city = $${params.length}`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows: staff } = await query(
    `SELECT id, full_name, role, region, sub_city FROM users ${whereSql} ORDER BY created_at ASC LIMIT 50`,
    params,
  );
  const candidates = (staff || []);

  // Rank candidates by real distance to their last reported position (nearest first),
  // then estimate arrival time (doc SD-4 / collaboration diagram steps 4-6).
  const positions = getRecentPositions();
  const scored = candidates.map((s) => {
    const pos = positions.get(s.id);
    const distance_m = (pos && alert.latitude != null && alert.longitude != null)
      ? haversine(alert.latitude, alert.longitude, pos.latitude, pos.longitude)
      : null;
    return {
      ...s,
      distance_m,
      eta_seconds: distance_m != null ? Math.round(distance_m / ASSUMED_SPEED_MPS) : null,
    };
  });
  scored.sort((a, b) => {
    if (a.distance_m == null && b.distance_m == null) return 0;
    if (a.distance_m == null) return 1;
    if (b.distance_m == null) return -1;
    return a.distance_m - b.distance_m;
  });

  const nearest = scored.slice(0, 3);
  const assignments = [];
  for (const staffUser of nearest) {
    const etaNote = staffUser.eta_seconds != null
      ? ` · ETA ~${Math.max(1, Math.round(staffUser.eta_seconds / 60))} min`
      : '';
    const { rows } = await query(
      `INSERT INTO dispatch_assignments (sos_id, assigned_to, assigned_by, notes, distance_m, eta_seconds)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [alert.id, staffUser.id, null,
        `Auto-dispatched to ${staffUser.full_name} (${staffUser.role})${etaNote}`,
        staffUser.distance_m, staffUser.eta_seconds],
    );
    assignments.push({
      ...rows[0],
      staff_name: staffUser.full_name,
      distance_m: staffUser.distance_m,
      eta_seconds: staffUser.eta_seconds,
    });
  }
  await query(
    `UPDATE sos_alerts SET status = CASE WHEN $2 > 0 THEN 'dispatched'::sos_status ELSE 'triggered'::sos_status END WHERE id = $1`,
    [alert.id, assignments.length],
  );
  const geofence = await evaluateGeofenceContext(alert);
  return { nearest, assignments, geofence };
}

export function haversine(lat1, lon1, lat2, lon2) {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return Infinity;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a));
}
