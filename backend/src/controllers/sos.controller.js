import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { dispatchSos, evaluateGeofenceContext } from '../services/dispatch.service.js';
import { io } from '../socket/socket.js';
import { sendSosAlertSms } from '../services/sms.service.js';
import { notifyGeofenceCitizens } from '../services/geofence-notify.service.js';
import { encrypt, decrypt } from '../utils/crypto.js';
import { resolveAddress } from '../services/geocode.service.js';
import { endLiveStreamsForSos } from './sos-live.controller.js';
import {
  findNearestPoliceStation,
  getRouteRecipients,
  notifyNearestStationOrCentral,
} from '../services/police-station.service.js';

const SOS_COLS = `s.*, u.full_name AS user_name, u.phone AS user_phone,
  ps.name AS station_name, ps.address_text AS station_address,
  CASE WHEN ps.is_active = true AND EXISTS (
    SELECT 1 FROM police_station_users psu
    JOIN users officer ON officer.id = psu.user_id
    WHERE psu.station_id = s.station_id AND officer.role = 'police' AND officer.is_active = true
  ) THEN 'nearest_station' ELSE 'central_dispatch' END AS dispatch_route,
  CASE WHEN ps.is_active = true AND EXISTS (
    SELECT 1 FROM police_station_users psu
    JOIN users officer ON officer.id = psu.user_id
    WHERE psu.station_id = s.station_id AND officer.role = 'police' AND officer.is_active = true
  ) THEN COALESCE((
    SELECT array_agg(psu.user_id)
    FROM police_station_users psu
    JOIN users officer ON officer.id = psu.user_id
    WHERE psu.station_id = s.station_id AND officer.role = 'police' AND officer.is_active = true
  ), ARRAY[]::uuid[]) ELSE COALESCE((
    SELECT array_agg(dispatcher.id) FROM users dispatcher
    WHERE dispatcher.role = 'dispatcher' AND dispatcher.is_active = true
  ), ARRAY[]::uuid[]) END AS route_recipient_ids`;

// address_text is PII and stored AES-256-GCM encrypted at rest.
const decryptRow = (row) => (row ? { ...row, address_text: decrypt(row.address_text) } : row);

export const createSos = async (req, res) => {
  const {
    latitude, longitude, address_text, description, region, sub_city, woreda,
    contacted_1, contacted_2,
  } = req.body;
  if ((latitude == null) !== (longitude == null)) {
    return fail(res, 'latitude and longitude must be provided together');
  }
  const station = latitude == null
    ? null
    : await findNearestPoliceStation({ latitude, longitude });
  const resolvedAddress = latitude == null
    ? (address_text || null)
    : await resolveAddress({ latitude, longitude, address_text, timeoutMs: 3000 });
  const { rows } = await query(
    `INSERT INTO sos_alerts (user_id, latitude, longitude, address_text, description, region, sub_city, woreda, contacted_1, contacted_2, station_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
    [req.user.id, latitude ?? null, longitude ?? null, resolvedAddress ? encrypt(resolvedAddress) : null, description || null,
      region || null, sub_city || null, woreda || null, contacted_1 || null, contacted_2 || null,
      station?.id ?? null],
  );
  const alert = {
    ...decryptRow(rows[0]),
    station_name: station?.name ?? null,
    station_address: station?.address_text ?? null,
  };
  const dispatch = await dispatchSos(alert);
  const recipients = await notifyNearestStationOrCentral('sos:new', alert, dispatch);
  dispatch.route = recipients.route;
  dispatch.recipient_count = recipients.userIds.length;
  dispatch.station_id = station?.id ?? null;
  dispatch.station_name = station?.name ?? null;
  dispatch.station_address = station?.address_text ?? null;

  // Notify citizens in the affected geofence area
  try {
    const geoNotify = await notifyGeofenceCitizens(alert);
    if (geoNotify && geoNotify.notifiedCount > 0) {
      console.log(`[GEOFENCE] Created ${geoNotify.notifiedCount} safety notice(s) for zones: ${geoNotify.zones.join(', ')}`);
    }
  } catch (err) {
    console.error('[GEOFENCE NOTIFY ERROR]', err.message);
  }

  // Send SMS to emergency contacts
  const smsLocation = resolvedAddress || (
    latitude != null ? `Lat: ${latitude}, Lng: ${longitude}` : 'Location unavailable; sent to central dispatch'
  );
  if (contacted_1) {
    await sendSosAlertSms(contacted_1, req.user.full_name || 'Citizen', smsLocation);
  }
  if (contacted_2) {
    await sendSosAlertSms(contacted_2, req.user.full_name || 'Citizen', smsLocation);
  }
  
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'create_sos','sos_alerts',$2)`,
    [req.user.id, alert.id],
  );
  ok(res, { alert, dispatch }, 'SOS alert sent', 201);
};

export const listSos = async (req, res) => {
  const { status, region, sub_city, page = 1, limit = 20 } = req.query;
  const where = [];
  const params = [];
  if (status) { params.push(status); where.push(`s.status = $${params.length}`); }
  if (region) { params.push(region); where.push(`s.region = $${params.length}`); }
  if (sub_city) { params.push(sub_city); where.push(`s.sub_city = $${params.length}`); }
  if (req.user.role === 'citizen') {
    params.push(req.user.id);
    where.push(`s.user_id = $${params.length}`);
  } else if (req.user.role === 'police') {
    params.push(req.user.id);
    where.push(`EXISTS (
      SELECT 1 FROM police_station_users psu
      JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
      JOIN users officer ON officer.id = psu.user_id
      WHERE psu.station_id = s.station_id AND psu.user_id = $${params.length}
        AND officer.role = 'police' AND officer.is_active = true
    )`);
  } else if (req.user.role === 'dispatcher') {
    where.push(`(s.station_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM police_station_users psu
      JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
      JOIN users officer ON officer.id = psu.user_id
      WHERE psu.station_id = s.station_id
        AND officer.role = 'police' AND officer.is_active = true
    ))`);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  params.push(parseInt(limit, 10), (parseInt(page, 10) - 1) * parseInt(limit, 10));
  const { rows } = await query(
    `SELECT ${SOS_COLS} FROM sos_alerts s LEFT JOIN users u ON u.id = s.user_id
     LEFT JOIN police_stations ps ON ps.id = s.station_id
     ${whereSql} ORDER BY s.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  const decrypted = rows.map(decryptRow);
  for (const alert of decrypted) {
    alert.geofence = await evaluateGeofenceContext(alert);
  }
  ok(res, decrypted);
};

export const getSos = async (req, res) => {
  if (!await hasSosAccess(req.user, req.params.id)) {
    return fail(res, 'This SOS is routed to another station', 403);
  }
  const { rows } = await query(
    `SELECT ${SOS_COLS} FROM sos_alerts s
     LEFT JOIN users u ON u.id = s.user_id
     LEFT JOIN police_stations ps ON ps.id = s.station_id
     WHERE s.id = $1`,
    [req.params.id],
  );
  if (!rows[0]) return fail(res, 'SOS not found', 404);
  ok(res, decryptRow(rows[0]));
};

export const updateSosStatus = async (req, res) => {
  if (!await hasSosAccess(req.user, req.params.id)) {
    return fail(res, 'This SOS is routed to another station', 403);
  }
  const { status, response_notes, dispatcher_id } = req.body;
  const valid = ['triggered', 'acknowledged', 'dispatched', 'resolved', 'cancelled'];
  if (!valid.includes(status)) return fail(res, `status must be one of ${valid.join(', ')}`);
  const { rows } = await query(
    `UPDATE sos_alerts SET status = $1, response_notes = COALESCE($2, response_notes),
       dispatcher_id = COALESCE($3, dispatcher_id),
       resolved_at = CASE WHEN $1 IN ('resolved','cancelled') THEN now() ELSE resolved_at END
     WHERE id = $4 RETURNING *`,
    [status, response_notes || null, dispatcher_id || null, req.params.id],
  );
  if (!rows[0]) return fail(res, 'SOS not found', 404);
  if (['resolved', 'cancelled'].includes(status)) {
    endLiveStreamsForSos(rows[0].id);
  }
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,'update_sos_status','sos_alerts',$2,$3)`,
    [req.user.id, rows[0].id, JSON.stringify({ status, response_notes })],
  );
  const ownerUserId = rows[0].user_id;
  if (ownerUserId) {
    io.to(`user:${ownerUserId}`).emit('sos:status', {
      sosId: rows[0].id,
      status: rows[0].status,
      response_notes: rows[0].response_notes,
    });
  }
  ok(res, decryptRow(rows[0]), 'SOS updated');
};

export const assignSos = async (req, res) => {
  const { assigned_to } = req.body;
  if (!assigned_to) return fail(res, 'assigned_to is required');
  const { rows: alerts } = await query(
    'SELECT station_id FROM sos_alerts WHERE id = $1',
    [req.params.id],
  );
  if (!alerts[0]) return fail(res, 'SOS not found', 404);
  const recipients = await getRouteRecipients(alerts[0].station_id);
  if (!recipients.userIds.includes(assigned_to)) {
    return fail(res, 'Assign this SOS only to the nearest station or central dispatch', 403);
  }
  const { rows } = await query(
    `INSERT INTO dispatch_assignments (sos_id, assigned_to, assigned_by) VALUES ($1,$2,$3) RETURNING *`,
    [req.params.id, assigned_to, req.user.id],
  );
  ok(res, rows[0], 'Dispatched', 201);
};

async function hasSosAccess(user, sosId) {
  const { rows } = await query(
    'SELECT user_id, station_id FROM sos_alerts WHERE id = $1',
    [sosId],
  );
  if (!rows[0]) return false;
  if (['system_admin', 'regional_admin'].includes(user.role)) return true;
  if (user.role === 'citizen') return rows[0].user_id === user.id;
  const recipients = await getRouteRecipients(rows[0].station_id);
  return recipients.userIds.includes(user.id);
}
