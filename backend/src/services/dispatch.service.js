import { query } from '../config/db.js';
import { getRecentPositions } from '../controllers/position.controller.js';
import { haversine } from './geo.service.js';

// Average urban police response speed assumed for ETA estimation (~40 km/h).
const ASSUMED_SPEED_MPS = 11.1;
export { haversine };

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
  const { rows: candidates } = alert.station_id
    ? await query(
      `SELECT u.id, u.full_name, u.role, u.region, u.sub_city
       FROM police_station_users psu
       JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
       JOIN users u ON u.id = psu.user_id
       WHERE psu.station_id = $1 AND u.role = 'police' AND u.is_active = true
       ORDER BY u.created_at ASC`,
      [alert.station_id],
    )
    : { rows: [] };

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
  return {
    nearest,
    assignments,
    geofence,
    station_id: alert.station_id || null,
  };
}
