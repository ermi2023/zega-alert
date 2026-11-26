import { query } from '../config/db.js';
import { io } from '../socket/socket.js';
import { nearestStationByLocation, selectRouteRecipients } from './station-routing.utils.js';

export async function findNearestPoliceStation({ latitude, longitude }) {
  if (latitude == null || longitude == null || latitude === '' || longitude === '') {
    return null;
  }
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    lat < -90 ||
    lat > 90 ||
    lng < -180 ||
    lng > 180
  ) {
    return null;
  }

  const { rows } = await query(
    `SELECT id, name, address_text, phone, region, sub_city, latitude, longitude
     FROM police_stations
     WHERE is_active = true
       AND NULLIF(BTRIM(address_text), '') IS NOT NULL
       AND latitude IS NOT NULL AND longitude IS NOT NULL`,
  );
  return nearestStationByLocation(lat, lng, rows);
}

export async function getStationStaffIds(stationId) {
  if (!stationId) return [];
  const { rows } = await query(
    `SELECT u.id
     FROM police_station_users psu
     JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
     JOIN users u ON u.id = psu.user_id
     WHERE psu.station_id = $1 AND u.role = 'police' AND u.is_active = true
     ORDER BY u.full_name`,
    [stationId],
  );
  return rows.map((row) => row.id);
}

export async function getCentralDispatcherIds() {
  const { rows } = await query(
    `SELECT id FROM users
     WHERE role = 'dispatcher' AND is_active = true
     ORDER BY created_at`,
  );
  return rows.map((row) => row.id);
}

export async function getRouteRecipients(stationId) {
  const stationUserIds = await getStationStaffIds(stationId);
  const dispatcherIds = stationUserIds.length ? [] : await getCentralDispatcherIds();
  return selectRouteRecipients(stationUserIds, dispatcherIds);
}

export async function notifyNearestStationOrCentral(
  event,
  data,
  dispatch = {},
) {
  const stationId = data.station_id || data.stationId || null;
  const recipients = await getRouteRecipients(stationId);
  const payload = {
    ...data,
    dispatch: {
      ...dispatch,
      route: recipients.route,
      station_id: stationId,
      recipient_count: recipients.userIds.length,
    },
  };
  for (const userId of recipients.userIds) {
    io.to(`user:${userId}`).emit(event, payload);
  }
  return recipients;
}
