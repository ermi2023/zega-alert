import { query } from '../config/db.js';
import { pushToUsers } from './notification.service.js';
import { isInsideGeofence } from './geo.service.js';

async function notifyCitizens({ scope, excludeUserId, title, body, metadata }) {
  if (!scope.region && !scope.sub_city) {
    return { notifiedCount: 0, reason: 'location_unavailable' };
  }

  const where = [`role = 'citizen'`, 'is_active = true'];
  const params = [];
  if (scope.region) {
    params.push(scope.region);
    where.push(`region = $${params.length}`);
  }
  if (scope.sub_city) {
    params.push(scope.sub_city);
    where.push(`sub_city = $${params.length}`);
  }
  if (scope.woreda) {
    params.push(scope.woreda);
    where.push(`woreda = $${params.length}`);
  }
  if (excludeUserId) {
    params.push(excludeUserId);
    where.push(`id != $${params.length}`);
  }

  const { rows: citizens } = await query(
    `SELECT id FROM users WHERE ${where.join(' AND ')}`,
    params,
  );
  if (!citizens.length) return { notifiedCount: 0, pushCount: 0 };

  const userIds = citizens.map((citizen) => citizen.id);
  await query(
    `INSERT INTO notifications (user_id, title, body, delivery_type, metadata)
     SELECT id, $2, $3, 'push', $4::jsonb
     FROM users
     WHERE id = ANY($1)`,
    [userIds, title, body, JSON.stringify(metadata)],
  );

  const deliveries = await pushToUsers(userIds, title, body, metadata);
  const failedDeliveries = deliveries.filter((delivery) => !delivery.ok).length;
  if (failedDeliveries > 0) {
    console.error(`[GEOFENCE NOTIFICATION] ${failedDeliveries} push delivery(s) failed`);
  }

  return {
    notifiedCount: citizens.length,
    pushCount: deliveries.filter((delivery) => delivery.ok).length,
  };
}

/** Save an area update in the inbox and push it to active citizens in that area. */
export async function notifyGeofenceChange(geofence, event) {
  const zoneName = geofence.label || geofence.name || 'safety zone';
  const region = geofence.region;
  const title = event === 'published'
    ? 'New safety zone'
    : event === 'deactivated' || event === 'removed'
    ? 'Safety zone no longer active'
    : 'Safety zone updated';
  const body = event === 'deactivated' || event === 'removed'
    ? `The official safety zone "${zoneName}" in ${region || 'your area'} is no longer active. Follow current instructions from local authorities.`
    : `Official safety-zone information for "${zoneName}" in ${region || 'your area'} is ${event === 'published' ? 'now available' : 'updated'}. Open Safety Zones on Home to review its boundary.`;

  return notifyCitizens({
    scope: geofence,
    title,
    body,
    metadata: {
      type: 'geofence_alert',
      event,
      geofenceId: String(geofence.id),
      zoneName,
    },
  });
}

/** Send an alert to citizens in an SOS region when it falls inside a public area. */
export async function notifyGeofenceCitizens(sosAlert) {
  if (sosAlert.latitude == null || sosAlert.longitude == null) return;

  // Find all active geofences that contain this SOS location.
  const { rows: zones } = await query(
    `SELECT id, name, label, type, center_lat, center_lng, radius_m, polygon
     FROM geofences
     WHERE is_active = true
       AND (created_by IS NULL OR EXISTS (
         SELECT 1 FROM users creator
         WHERE creator.id = geofences.created_by
           AND creator.role IN ('police', 'dispatcher', 'regional_admin', 'system_admin')
       ))`,
  );

  const affectedZones = zones.filter((zone) =>
    isInsideGeofence(sosAlert.latitude, sosAlert.longitude, zone));

  if (!affectedZones.length) return;

  const zoneNames = affectedZones.map((zone) => zone.label || zone.name).join(', ');
  const title = 'Emergency reported in a safety zone';
  const body = `An emergency has been reported within ${zoneNames}. Avoid the affected area if safe to do so and follow instructions from local authorities.`;

  const result = await notifyCitizens({
    scope: sosAlert,
    excludeUserId: sosAlert.user_id,
    title,
    body,
    metadata: {
      type: 'geofence_alert',
      event: 'incident',
      geofenceId: String(affectedZones[0].id),
      geofenceIds: affectedZones.map((zone) => String(zone.id)),
      sosId: String(sosAlert.id || ''),
      zones: zoneNames,
    },
  });

  return {
    ...result,
    zones: affectedZones.map((zone) => zone.label || zone.name),
  };
}
