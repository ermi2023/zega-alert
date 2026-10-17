import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { dispatchSos, evaluateGeofenceContext } from '../services/dispatch.service.js';
import { notifyStaff } from '../services/notification.service.js';
import { io } from '../socket/socket.js';
import { sendSosAlertSms } from '../services/sms.service.js';
import { notifyGeofenceCitizens } from '../services/geofence-notify.service.js';
import { encrypt, decrypt } from '../utils/crypto.js';
import { resolveAddress } from '../services/geocode.service.js';

const SOS_COLS = `s.*, u.full_name AS user_name, u.phone AS user_phone`;

// address_text is PII and stored AES-256-GCM encrypted at rest.
const decryptRow = (row) => (row ? { ...row, address_text: decrypt(row.address_text) } : row);

export const createSos = async (req, res) => {
  const {
    latitude, longitude, address_text, description, region, sub_city, woreda,
    contacted_1, contacted_2,
  } = req.body;
  if (latitude == null || longitude == null) return fail(res, 'latitude and longitude are required');
  const resolvedAddress = await resolveAddress({ latitude, longitude, address_text, timeoutMs: 3000 });
  const { rows } = await query(
    `INSERT INTO sos_alerts (user_id, latitude, longitude, address_text, description, region, sub_city, woreda, contacted_1, contacted_2)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
    [req.user.id, latitude, longitude, encrypt(resolvedAddress), description || null,
      region || null, sub_city || null, woreda || null, contacted_1 || null, contacted_2 || null],
  );
  const alert = decryptRow(rows[0]);
  const dispatch = await dispatchSos(alert);
  await notifyStaff('sos:new', alert, dispatch);

  // Notify citizens in the affected geofence area
  try {
    const geoNotify = await notifyGeofenceCitizens(alert, dispatch.geofence);
    if (geoNotify && geoNotify.notifiedCount > 0) {
      console.log(`[GEOFENCE] Notified ${geoNotify.notifiedCount} citizens in zones: ${geoNotify.zones.join(', ')}`);
    }
  } catch (err) {
    console.error('[GEOFENCE NOTIFY ERROR]', err.message);
  }

  // Send SMS to emergency contacts
  const smsLocation = resolvedAddress || `Lat: ${latitude}, Lng: ${longitude}`;
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
  if (req.user.role === 'citizen') { params.push(req.user.id); where.push(`s.user_id = $${params.length}`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  params.push(parseInt(limit, 10), (parseInt(page, 10) - 1) * parseInt(limit, 10));
  const { rows } = await query(
    `SELECT ${SOS_COLS} FROM sos_alerts s LEFT JOIN users u ON u.id = s.user_id
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
  const { rows } = await query(
    `SELECT ${SOS_COLS} FROM sos_alerts s LEFT JOIN users u ON u.id = s.user_id WHERE s.id = $1`,
    [req.params.id],
  );
  if (!rows[0]) return fail(res, 'SOS not found', 404);
  ok(res, decryptRow(rows[0]));
};

export const updateSosStatus = async (req, res) => {
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
  const { rows } = await query(
    `INSERT INTO dispatch_assignments (sos_id, assigned_to, assigned_by) VALUES ($1,$2,$3) RETURNING *`,
    [req.params.id, assigned_to, req.user.id],
  );
  ok(res, rows[0], 'Dispatched', 201);
};
