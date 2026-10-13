import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { notifyStaff } from '../services/notification.service.js';
import { sendSms } from '../services/sms.service.js';

// Great-circle distance in metres.
const haversine = (lat1, lng1, lat2, lng2) => {
  if ([lat1, lng1, lat2, lng2].some((v) => v === null || v === undefined)) return Infinity;
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

const findNearestStation = async ({ latitude, longitude, region }) => {
  const { rows } = await query(
    `SELECT * FROM police_stations
     WHERE is_active = true AND ($1::text IS NULL OR region = $1 OR region IS NULL)`,
    [region || null],
  );
  if (!rows.length) {
    const { rows: all } = await query('SELECT * FROM police_stations WHERE is_active = true');
    rows.push(...all);
  }
  if (!rows.length) return null;
  let best = rows[0];
  let bestD = Infinity;
  for (const s of rows) {
    const d = haversine(latitude, longitude, s.latitude, s.longitude);
    if (d < bestD) { bestD = d; best = s; }
  }
  return { ...best, distance_m: Number.isFinite(bestD) ? Math.round(bestD) : null };
};

/**
 * UC-4: Citizen (People of Determination) requests a simplified direct call.
 * The system retrieves GPS, finds the nearest police station and submits a
 * call request to the station's registered number.
 */
export const requestDirectCall = async (req, res) => {
  const { latitude, longitude } = req.body;
  const me = await query('SELECT id, phone, region, sub_city FROM users WHERE id = $1', [req.user.id]);
  const user = me.rows[0];
  const station = await findNearestStation({ latitude, longitude, region: user.region });

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

  notifyStaff('pod:direct_call', {
    request_id: request.id,
    region: user.region,
    citizen_phone: user.phone,
    station_name: station?.name,
    station_phone: station?.phone,
    latitude, longitude,
  }).catch(() => {});

  if (station?.phone) {
    sendSms(station.phone, `ZEGA-ALERT: A Person of Determination has requested a call. Citizen ${user.phone || 'unknown'} at ${latitude ?? '?'},${longitude ?? '?'}. Ref ${request.id}.`).catch(() => {});
  }

  ok(res, {
    request,
    station: station ? { id: station.id, name: station.name, phone: station.phone, distance_m: station.distance_m } : null,
  }, 'Direct call request submitted to the nearest police station', 201);
};

export const listDirectCalls = async (req, res) => {
  const { status } = req.query;
  const params = [];
  let where = '';
  if (status) { params.push(status); where = 'WHERE d.status = $1'; }
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
  const { rows } = await query(
    `INSERT INTO sign_language_messages (user_id, report_id, video_url, note, latitude, longitude)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [req.user.id, report_id || null, video_url, note || null, latitude ?? null, longitude ?? null],
  );
  const message = rows[0];
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'pod_sign_language','sign_language_messages',$2)`,
    [req.user.id, message.id],
  );
  notifyStaff('pod:sign_language', {
    message_id: message.id,
    region: req.user.region,
    video_url,
    note,
    latitude, longitude,
  }).catch(() => {});
  ok(res, message, 'Sign language message submitted', 201);
};

export const listSignLanguage = async (req, res) => {
  const { rows } = await query(
    `SELECT s.*, u.full_name AS citizen_name, u.region
     FROM sign_language_messages s LEFT JOIN users u ON u.id = s.user_id
     ORDER BY s.created_at DESC LIMIT 100`,
  );
  ok(res, rows);
};

export const listStations = async (req, res) => {
  const { region } = req.query;
  const params = [];
  let where = 'WHERE is_active = true';
  if (region) { params.push(region); where += ' AND (region = $1 OR region IS NULL)'; }
  const { rows } = await query(`SELECT * FROM police_stations ${where} ORDER BY name`, params);
  ok(res, rows);
};

export const createStation = async (req, res) => {
  const { name, phone, region, sub_city, latitude, longitude } = req.body;
  if (!name) return fail(res, 'name is required');
  const { rows } = await query(
    `INSERT INTO police_stations (name, phone, region, sub_city, latitude, longitude)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [name, phone || null, region || null, sub_city || null, latitude ?? null, longitude ?? null],
  );
  ok(res, rows[0], 'Station created', 201);
};
