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

  // Find all geofences that contain this SOS location
  const { rows: zones } = await query(
    `SELECT id, name, type, center_lat, center_lng, radius_m FROM geofences
     WHERE center_lat IS NOT NULL AND center_lng IS NOT NULL`,
  );

  const affectedZones = [];
  for (const zone of zones) {
    const dist = haversine(sosAlert.latitude, sosAlert.longitude, zone.center_lat, zone.center_lng);
    const radius = zone.radius_m || 500;
    if (dist <= radius) {
      affectedZones.push(zone);
    }
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

  const zoneNames = affectedZones.map(z => z.name).join(', ');
  const title = 'Safety Alert';
  const body = `An emergency incident has been reported near ${zoneNames}. Stay alert and avoid the area if possible.`;

  const results = [];
  for (const citizen of citizens) {
    // Skip the person who triggered the SOS
    if (citizen.id === sosAlert.user_id) continue;

    const pushResult = await sendFcmPush(citizen.device_token, title, body, {
      type: 'geofence_alert',
      sosId: String(sosAlert.id || ''),
      zones: zoneNames,
    });
    results.push({ userId: citizen.id, push: pushResult });
  }

  return { notifiedCount: results.length, zones: affectedZones.map(z => z.name) };
}
