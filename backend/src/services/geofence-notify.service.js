import { query } from '../config/db.js';
import { sendFcmPush } from './notification.service.js';
import { sendNotificationSms } from './sms.service.js';
import { haversine } from './dispatch.service.js';

/**
 * When an SOS is created inside a geofence, notify citizens in that zone
 * about the incident (non-emergency warning).
 */
export async function notifyGeofenceCitizens(sosAlert, geofenceContext) {
  if (!sosAlert.latitude || !sosAlert.longitude) return;

  // Find all active geofences that contain this SOS location.
  const { rows: zones } = await query(
    `SELECT id, name, label, type, center_lat, center_lng, radius_m, polygon, sensitivity
     FROM geofences WHERE is_active = true`,
  );

  const affectedZones = [];
  for (const zone of zones) {
    const insidePolygon = pointInPolygon(sosAlert.latitude, sosAlert.longitude, zone.polygon);
    const dist = zone.center_lat != null && zone.center_lng != null
      ? haversine(sosAlert.latitude, sosAlert.longitude, zone.center_lat, zone.center_lng)
      : Infinity;
    // Sensitivity scales the trigger radius: high = wider net, low = tighter.
    const multiplier = { high: 1.25, medium: 1, low: 0.75 }[zone.sensitivity] || 1;
    const radius = (zone.radius_m || 500) * multiplier;
    if (insidePolygon || dist <= radius) affectedZones.push(zone);
  }

  if (!affectedZones.length) return;

  // Find citizens in the same region/sub_city who have device tokens
  const region = sosAlert.region;
  const subCity = sosAlert.sub_city;

  if (!region && !subCity) return;

  const where = [`role = 'citizen'`, `is_active = true`];
  const params = [];
  if (region) { params.push(region); where.push(`region = $${params.length}`); }
  if (subCity) { params.push(subCity); where.push(`sub_city = $${params.length}`); }

  const { rows: citizens } = await query(
    `SELECT id, device_token, phone, full_name FROM users
     WHERE ${where.join(' AND ')} AND device_token IS NOT NULL AND device_token != ''`,
    params,
  );

  if (!citizens.length) return;

  const zoneNames = affectedZones.map(z => z.label || z.name).join(', ');
  const highSensitivity = affectedZones.some(z => z.sensitivity === 'high');
  const title = highSensitivity ? 'High-sensitivity Safety Alert' : 'Safety Alert';
  const body = `An emergency incident has been reported near ${zoneNames}. Stay alert and avoid the area if possible.`;

  const results = [];
  for (const citizen of citizens) {
    // Skip the person who triggered the SOS
    if (citizen.id === sosAlert.user_id) continue;

    const pushResult = await sendFcmPush(citizen.device_token, title, body, {
      type: 'geofence_alert',
      sosId: String(sosAlert.id || ''),
      zones: zoneNames,
      sensitivity: highSensitivity ? 'high' : undefined,
    });
    let smsResult = null;
    if (highSensitivity && citizen.phone) {
      smsResult = await sendNotificationSms(citizen.phone, `${title}: ${body}`).catch(() => null);
    }
    results.push({ userId: citizen.id, push: pushResult, sms: smsResult });
  }

  return { notifiedCount: results.length, zones: affectedZones.map(z => z.label || z.name) };
}

// Ray-casting point-in-polygon; accepts [[lat,lng], ...] or [{lat,lng}, ...].
function pointInPolygon(lat, lng, polygon) {
  if (!Array.isArray(polygon) || polygon.length < 3) return false;
  const pts = polygon.map((p) => Array.isArray(p)
    ? { lat: Number(p[0]), lng: Number(p[1]) }
    : { lat: Number(p.lat ?? p.latitude), lng: Number(p.lng ?? p.longitude) });
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const xi = pts[i].lng; const yi = pts[i].lat;
    const xj = pts[j].lng; const yj = pts[j].lat;
    const intersect = ((yi > lat) !== (yj > lat))
      && (lng < ((xj - xi) * (lat - yi)) / ((yj - yi) || 1e-12) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}
