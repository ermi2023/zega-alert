import { pool, query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { sendSms } from '../services/sms.service.js';
import {
  findNearestPoliceStation,
  getRouteRecipients,
  notifyNearestStationOrCentral,
} from '../services/police-station.service.js';
import { isUuid } from '../utils/uuid.js';

/**
 * UC-4: Citizen (People of Determination) requests a simplified direct call.
 * The system retrieves GPS, finds the nearest police station and submits a
 * call request to the station's registered number.
 */
export const requestDirectCall = async (req, res) => {
  const { latitude, longitude } = req.body;
  const me = await query('SELECT id, phone, region, sub_city FROM users WHERE id = $1', [req.user.id]);
  const user = me.rows[0];
  const station = await findNearestPoliceStation({ latitude, longitude });

  const { rows } = await query(
    `INSERT INTO direct_call_requests
       (user_id, citizen_phone, latitude, longitude, station_id, station_name, station_phone)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [user.id, user.phone, latitude ?? null, longitude ?? null,
      station?.id ?? null, station?.name ?? null, station?.phone ?? null],
  );
  const request = rows[0];

  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'pod_direct_call','direct_call_requests',$2)`,
    [user.id, request.id],
  );

  await notifyNearestStationOrCentral('pod:direct_call', {
    request_id: request.id,
    region: user.region,
    citizen_phone: user.phone,
    station_id: station?.id ?? null,
    station_name: station?.name,
    station_phone: station?.phone,
    latitude, longitude,
  }).catch((error) => console.error('[POD DIRECT CALL NOTIFY]', error.message));

  if (station?.phone) {
    sendSms(station.phone, `ZEGA-ALERT: A Person of Determination has requested a call. Citizen ${user.phone || 'unknown'} at ${latitude ?? '?'},${longitude ?? '?'}. Ref ${request.id}.`)
      .catch((error) => console.error('[POD DIRECT CALL SMS]', error.message));
  }

  ok(res, {
    request,
    station: station ? { id: station.id, name: station.name, address_text: station.address_text, phone: station.phone, distance_m: station.distance_m } : null,
  }, 'Direct call request submitted to the nearest police station', 201);
};

export const listDirectCalls = async (req, res) => {
  const { status } = req.query;
  const params = [];
  let where = '';
  if (status) { params.push(status); where = 'WHERE d.status = $1'; }
  if (req.user.role === 'police') {
    params.push(req.user.id);
    where += `${where ? ' AND' : 'WHERE'} EXISTS (
      SELECT 1 FROM police_station_users psu
      JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
      JOIN users officer ON officer.id = psu.user_id
      WHERE psu.station_id = d.station_id AND psu.user_id = $${params.length}
        AND officer.role = 'police' AND officer.is_active = true
    )`;
  } else if (req.user.role === 'dispatcher') {
    where += `${where ? ' AND' : 'WHERE'} (d.station_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM police_station_users psu
      JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
      JOIN users officer ON officer.id = psu.user_id
      WHERE psu.station_id = d.station_id AND officer.role = 'police' AND officer.is_active = true
    ))`;
  }
  const { rows } = await query(
    `SELECT d.*, u.full_name AS citizen_name, u.region
     FROM direct_call_requests d LEFT JOIN users u ON u.id = d.user_id
     ${where} ORDER BY d.created_at DESC LIMIT 100`,
    params,
  );
  ok(res, rows);
};

export const updateDirectCall = async (req, res) => {
  const { status, notes } = req.body;
  const { rows: existing } = await query(
    'SELECT station_id FROM direct_call_requests WHERE id = $1',
    [req.params.id],
  );
  if (!existing[0]) return fail(res, 'Not found', 404);
  if (!['regional_admin', 'system_admin'].includes(req.user.role)) {
    const recipients = await getRouteRecipients(existing[0].station_id);
    if (!recipients.userIds.includes(req.user.id)) {
      return fail(res, 'This request is routed to another station', 403);
    }
  }
  const { rows } = await query(
    `UPDATE direct_call_requests SET status = COALESCE($1, status), notes = COALESCE($2, notes),
       handled_by = $3, completed_at = CASE WHEN $1 IN ('completed','cancelled') THEN now() ELSE completed_at END
     WHERE id = $4 RETURNING *`,
    [status || null, notes || null, req.user.id, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  ok(res, rows[0], 'Request updated');
};

/**
 * UC-5: Hearing-impaired citizen submits a sign language video message as
 * part of a report or emergency communication.
 */
export const submitSignLanguage = async (req, res) => {
  const { video_url, note, latitude, longitude, report_id } = req.body;
  if (!video_url) return fail(res, 'video_url is required');
  let stationId = null;
  let report = null;
  if (report_id) {
    if (!isUuid(report_id)) return fail(res, 'Invalid report id');
    const reportResult = await query(
      'SELECT station_id, reporter_id FROM reports WHERE id = $1',
      [report_id],
    );
    report = reportResult.rows[0];
    if (!report) return fail(res, 'Report not found', 404);
    if (req.user.role === 'citizen' && report.reporter_id !== req.user.id) {
      return fail(res, 'Not your report', 403);
    }
    stationId = report.station_id ?? null;
  }
  if (!stationId) {
    const station = await findNearestPoliceStation({ latitude, longitude });
    stationId = station?.id ?? null;
  }
  if (req.user.role === 'police' || req.user.role === 'dispatcher') {
    const recipients = await getRouteRecipients(stationId);
    if (!recipients.userIds.includes(req.user.id)) {
      return fail(res, 'This message is routed to another station', 403);
    }
  } else if (!['citizen', 'regional_admin', 'system_admin'].includes(req.user.role)) {
    return fail(res, 'Not authorized to submit a sign language message', 403);
  }
  const { rows } = await query(
    `INSERT INTO sign_language_messages (user_id, report_id, video_url, note, latitude, longitude, station_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [req.user.id, report_id || null, video_url, note || null, latitude ?? null, longitude ?? null, stationId],
  );
  const message = rows[0];
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'pod_sign_language','sign_language_messages',$2)`,
    [req.user.id, message.id],
  );
  await notifyNearestStationOrCentral('pod:sign_language', {
    message_id: message.id,
    region: req.user.region,
    station_id: stationId,
    video_url,
    note,
    latitude, longitude,
  }).catch((error) => console.error('[POD SIGN LANGUAGE NOTIFY]', error.message));
  ok(res, message, 'Sign language message submitted', 201);
};

export const listSignLanguage = async (req, res) => {
  const params = [];
  let where = '';
  if (req.user.role === 'police') {
    params.push(req.user.id);
    where = `WHERE EXISTS (
      SELECT 1 FROM police_station_users psu
      JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
      JOIN users officer ON officer.id = psu.user_id
      WHERE psu.station_id = s.station_id AND psu.user_id = $1
        AND officer.role = 'police' AND officer.is_active = true
    )`;
  } else if (req.user.role === 'dispatcher') {
    where = `WHERE (s.station_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM police_station_users psu
      JOIN police_stations station ON station.id = psu.station_id AND station.is_active = true
      JOIN users officer ON officer.id = psu.user_id
      WHERE psu.station_id = s.station_id AND officer.role = 'police' AND officer.is_active = true
    ))`;
  }
  const { rows } = await query(
    `SELECT s.*, u.full_name AS citizen_name, u.region
     FROM sign_language_messages s LEFT JOIN users u ON u.id = s.user_id
     ${where}
     ORDER BY s.created_at DESC LIMIT 100`,
    params,
  );
  ok(res, rows);
};

export const listStations = async (req, res) => {
  const params = [];
  let where = '';
  if (req.user.role === 'regional_admin') {
    params.push(req.user.region);
    where = 'WHERE ps.region = $1';
  }
  const { rows } = await query(
    `SELECT ps.*,
       COALESCE(array_agg(psu.user_id) FILTER (WHERE psu.user_id IS NOT NULL), '{}') AS staff_user_ids
     FROM police_stations ps
     LEFT JOIN police_station_users psu ON psu.station_id = ps.id
     ${where}
     GROUP BY ps.id ORDER BY ps.name`,
    params,
  );
  ok(res, rows);
};

export const listStationStaff = async (req, res) => {
  const params = [];
  let where = `WHERE role = 'police' AND is_active = true`;
  if (req.user.role === 'regional_admin') {
    params.push(req.user.region);
    where += ` AND region = $1`;
  }
  const { rows } = await query(
    `SELECT id, full_name, phone, region, sub_city FROM users ${where} ORDER BY full_name`,
    params,
  );
  ok(res, rows);
};

const validateStationInput = (body, user) => {
  const { name, address_text, phone, sub_city, latitude, longitude, is_active } = body;
  const region = user.role === 'regional_admin' ? user.region : body.region;
  const clean = (value) => typeof value === 'string' ? value.trim() : '';
  if (
    !clean(name) ||
    !clean(address_text) ||
    !clean(region) ||
    latitude == null || latitude === '' ||
    longitude == null || longitude === ''
  ) {
    return { error: 'name, address_text, region, latitude, and longitude are required' };
  }
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (
    !Number.isFinite(lat) || lat < -90 || lat > 90 ||
    !Number.isFinite(lng) || lng < -180 || lng > 180
  ) {
    return { error: 'Valid latitude and longitude are required' };
  }
  return {
    value: {
      name: clean(name),
      address_text: clean(address_text),
      phone: clean(phone) || null,
      region: clean(region),
      sub_city: clean(sub_city) || null,
      latitude: lat,
      longitude: lng,
      is_active: is_active ?? true,
    },
  };
};

const saveStationUsers = async (client, stationId, userIds, region) => {
  if (!Array.isArray(userIds)) return { error: 'staff_user_ids must be an array' };
  const uniqueIds = [...new Set(userIds.map((id) => String(id)))];
  if (uniqueIds.some((id) => !isUuid(id))) return { error: 'Invalid staff user id' };
  if (uniqueIds.length) {
    const params = [uniqueIds];
    let regionSql = '';
    if (region) {
      params.push(region);
      regionSql = ` AND region = $2`;
    }
    const { rows } = await client.query(
      `SELECT id FROM users
       WHERE id = ANY($1::uuid[]) AND role = 'police' AND is_active = true${regionSql}`,
      params,
    );
    if (rows.length !== uniqueIds.length) {
      return { error: 'All assigned users must be active police officers in this region' };
    }
  }
  await client.query('DELETE FROM police_station_users WHERE station_id = $1', [stationId]);
  for (const userId of uniqueIds) {
    await client.query(
      'INSERT INTO police_station_users (station_id, user_id) VALUES ($1,$2)',
      [stationId, userId],
    );
  }
  return { userIds: uniqueIds };
};

export const createStation = async (req, res) => {
  const { value, error } = validateStationInput(req.body, req.user);
  if (error) return fail(res, error);
  const userIds = req.body.staff_user_ids ?? [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO police_stations (name, address_text, phone, region, sub_city, latitude, longitude, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [value.name, value.address_text, value.phone, value.region, value.sub_city,
        value.latitude, value.longitude, value.is_active],
    );
    const membership = await saveStationUsers(client, rows[0].id, userIds, req.user.role === 'regional_admin' ? req.user.region : null);
    if (membership.error) {
      await client.query('ROLLBACK');
      return fail(res, membership.error);
    }
    await client.query('COMMIT');
    ok(res, { ...rows[0], staff_user_ids: membership.userIds }, 'Station created', 201);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export const updateStation = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid station id', 400);
  const existing = await query('SELECT region FROM police_stations WHERE id = $1', [req.params.id]);
  if (!existing.rows[0]) return fail(res, 'Station not found', 404);
  if (req.user.role === 'regional_admin' && existing.rows[0].region !== req.user.region) {
    return fail(res, 'You can only manage stations in your region', 403);
  }
  const { value, error } = validateStationInput(req.body, req.user);
  if (error) return fail(res, error);
  const userIds = req.body.staff_user_ids ?? [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `UPDATE police_stations
       SET name = $2, address_text = $3, phone = $4, region = $5, sub_city = $6,
           latitude = $7, longitude = $8, is_active = $9
       WHERE id = $1 RETURNING *`,
      [req.params.id, value.name, value.address_text, value.phone, value.region,
        value.sub_city, value.latitude, value.longitude, value.is_active],
    );
    const membership = await saveStationUsers(client, req.params.id, userIds, req.user.role === 'regional_admin' ? req.user.region : null);
    if (membership.error) {
      await client.query('ROLLBACK');
      return fail(res, membership.error);
    }
    await client.query('COMMIT');
    ok(res, { ...rows[0], staff_user_ids: membership.userIds }, 'Station updated');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};
