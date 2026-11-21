import { randomUUID } from 'crypto';
import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { isUuid } from '../utils/uuid.js';
import { io } from '../socket/socket.js';

const MODES = ['voice', 'video', 'chat'];
const ACTIVE = ['pending', 'rescheduled', 'accepted'];

const audit = (userId, action, entityId, detail) => query(
  `INSERT INTO audit_log (user_id, action, entity, entity_id, detail)
   VALUES ($1, $2, 'callback_requests', $3, $4)`,
  [userId, action, entityId, detail ? JSON.stringify(detail) : null],
).catch(() => {});

const notifyUser = async (userId, title, body, metadata = {}) => {
  if (!userId) return;
  const { rows } = await query(
    `INSERT INTO notifications (user_id, title, body, delivery_type, metadata)
     VALUES ($1,$2,$3,'in_app',$4) RETURNING *`,
    [userId, title, body, JSON.stringify(metadata)],
  );
  io.to(`user:${userId}`).emit('notification:new', rows[0]);
};

const futureDate = (value) => {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date;
};

export const requestCallback = async (req, res) => {
  const { report_id, citizen_id, requested_slot, mode = 'voice', notes } = req.body;
  if (!report_id || !citizen_id) return fail(res, 'report_id and citizen_id required');
  if (!isUuid(report_id) || !isUuid(citizen_id)) return fail(res, 'Invalid id format', 400);
  if (!MODES.includes(mode)) return fail(res, `mode must be one of ${MODES.join(', ')}`);
  const citizen = await query('SELECT id, full_name, role FROM users WHERE id = $1', [citizen_id]);
  if (!citizen.rows[0] || citizen.rows[0].role !== 'citizen') return fail(res, 'citizen not found', 404);
  const slot = futureDate(requested_slot);
  if (requested_slot && !slot) return fail(res, 'requested_slot must be a valid date');
  if (slot && slot.getTime() < Date.now()) return fail(res, 'requested_slot must be in the future');
  const { rows } = await query(
    `INSERT INTO callback_requests (report_id, citizen_id, officer_id, requested_slot, mode, notes)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [report_id, citizen_id, req.user.id, slot, mode, notes || null],
  );
  await notifyUser(
    citizen_id,
    'Callback requested',
    `An officer requested a ${mode} callback${slot ? ` for ${slot.toLocaleString()}` : ''}.`,
    { type: 'callback', callbackId: rows[0].id },
  );
  io.to(`user:${citizen_id}`).emit('callback:new', rows[0]);
  await audit(req.user.id, 'request_callback', rows[0].id, { report_id, citizen_id, mode });
  ok(res, rows[0], 'Callback requested', 201);
};

export const respondToCallback = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid callback id', 400);
  const { status, proposed_slot, requested_slot, mode, notes } = req.body;
  if (status && !['accepted', 'declined', 'completed', 'rescheduled', 'cancelled'].includes(status)) {
    return fail(res, 'Invalid callback status');
  }
  if (mode && !MODES.includes(mode)) return fail(res, `mode must be one of ${MODES.join(', ')}`);

  const existing = await query('SELECT * FROM callback_requests WHERE id = $1', [req.params.id]);
  const cb = existing.rows[0];
  if (!cb) return fail(res, 'Callback not found', 404);
  const isCitizen = cb.citizen_id === req.user.id;
  const isOfficer = cb.officer_id === req.user.id;
  const isAdmin = ['system_admin', 'regional_admin', 'dispatcher'].includes(req.user.role);
  if (!isCitizen && !isOfficer && !isAdmin) return fail(res, 'Forbidden', 403);
  if (isCitizen && !ACTIVE.includes(cb.status)) return fail(res, 'This callback is already closed', 409);

  const newSlot = futureDate(proposed_slot || requested_slot);
  if ((proposed_slot || requested_slot) && !newSlot) return fail(res, 'Slot must be a valid date');
  if (newSlot && newSlot.getTime() < Date.now()) return fail(res, 'Slot must be in the future');

  const updates = [];
  const params = [];
  const set = (sql, value) => { params.push(value); updates.push(`${sql} = $${params.length}`); };

  if (newSlot) {
    if (isCitizen) set('proposed_slot', newSlot);
    else set('requested_slot', newSlot);
  }
  if (mode) set('mode', mode);
  if (notes !== undefined) set('notes', notes || null);

  let finalStatus = status;
  if (isCitizen && newSlot && !status) finalStatus = 'rescheduled';
  if (isCitizen && newSlot && status === 'accepted') finalStatus = 'rescheduled';
  if (!isCitizen && status === 'accepted' && cb.proposed_slot && !newSlot) {
    set('requested_slot', cb.proposed_slot);
    set('proposed_slot', null);
  }
  if (!finalStatus && updates.length === 0) return fail(res, 'No changes supplied');
  if (finalStatus) set('status', finalStatus);
  if (finalStatus && ['accepted', 'declined', 'completed', 'rescheduled', 'cancelled'].includes(finalStatus)) {
    set('responded_at', new Date());
  }
  if (!isCitizen && finalStatus === 'accepted') set('reminder_sent_at', null);

  params.push(req.params.id);
  const { rows } = await query(
    `UPDATE callback_requests SET ${updates.join(', ')} WHERE id = $${params.length} RETURNING *`,
    params,
  );

  const updated = rows[0];
  const when = updated.requested_slot ? new Date(updated.requested_slot).toLocaleString() : 'a new time';
  if (isCitizen) {
    await notifyUser(
      updated.officer_id,
      updated.proposed_slot ? 'Citizen proposed a new time' : 'Callback updated',
      updated.proposed_slot
        ? `The citizen proposed ${new Date(updated.proposed_slot).toLocaleString()} for the callback.`
        : `The citizen marked the callback as ${updated.status}.`,
      { type: 'callback', callbackId: updated.id },
    );
    io.to(`user:${updated.officer_id}`).emit('callback:update', updated);
  } else {
    await notifyUser(
      updated.citizen_id,
      updated.status === 'accepted' ? 'Callback confirmed' : 'Callback updated',
      updated.status === 'accepted'
        ? `Your ${updated.mode} callback is confirmed for ${when}.`
        : `Your callback was marked ${updated.status}.`,
      { type: 'callback', callbackId: updated.id },
    );
    io.to(`user:${updated.citizen_id}`).emit('callback:update', updated);
  }
  await audit(req.user.id, `callback_${updated.status}`, updated.id, {
    status: updated.status,
    requested_slot: updated.requested_slot,
    proposed_slot: updated.proposed_slot,
  });
  ok(res, updated, `Callback ${updated.status}`);
};

// Creates in-app reminders for confirmed callbacks happening within 24h.
export const sendDueCallbackReminders = async (userId) => {
  const { rows } = await query(
    `SELECT * FROM callback_requests
     WHERE (citizen_id = $1 OR officer_id = $1)
       AND status = 'accepted'
       AND requested_slot IS NOT NULL
       AND requested_slot BETWEEN now() AND now() + interval '24 hours'
       AND reminder_sent_at IS NULL`,
    [userId],
  );
  for (const cb of rows) {
    await notifyUser(
      cb.citizen_id,
      'Callback reminder',
      `Reminder: your ${cb.mode} callback is scheduled for ${new Date(cb.requested_slot).toLocaleString()}.`,
      { type: 'callback_reminder', callbackId: cb.id, mode: cb.mode },
    );
    await query('UPDATE callback_requests SET reminder_sent_at = now() WHERE id = $1', [cb.id]);
  }
  return rows.length;
};

export const startCallbackSession = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid callback id', 400);
  const { rows } = await query('SELECT * FROM callback_requests WHERE id = $1', [req.params.id]);
  const cb = rows[0];
  if (!cb) return fail(res, 'Callback not found', 404);
  const allowed = [cb.citizen_id, cb.officer_id].includes(req.user.id)
    || ['system_admin', 'regional_admin', 'dispatcher'].includes(req.user.role);
  if (!allowed) return fail(res, 'Forbidden', 403);
  if (!['accepted', 'rescheduled'].includes(cb.status)) {
    return fail(res, 'Callback must be confirmed before starting a session', 409);
  }
  const sessionId = randomUUID();
  const updated = await query(
    `UPDATE callback_requests SET session_id = $1, session_started_at = now(), status = 'accepted'
     WHERE id = $2 RETURNING *`,
    [sessionId, cb.id],
  );
  const room = { sessionId, callbackId: cb.id, mode: cb.mode, status: 'started' };
  io.to(`user:${cb.citizen_id}`).emit('callback:session', room);
  if (cb.officer_id) io.to(`user:${cb.officer_id}`).emit('callback:session', room);
  await audit(req.user.id, 'start_callback_session', cb.id, { session_id: sessionId, mode: cb.mode });
  ok(res, { ...updated.rows[0], session_url: `/callbacks/session/${sessionId}` }, 'Session started');
};

export const listCallbacks = async (req, res) => {
  await sendDueCallbackReminders(req.user.id);
  const { status } = req.query;
  const params = [req.user.id];
  let whereSql = '';
  if (status) { params.push(status); whereSql = `AND c.status = $${params.length}`; }
  const { rows } = await query(
    `SELECT c.*, u.full_name AS citizen_name, u.phone AS citizen_phone,
       o.full_name AS officer_name, r.title AS report_title
     FROM callback_requests c
     LEFT JOIN users u ON u.id = c.citizen_id
     LEFT JOIN users o ON o.id = c.officer_id
     LEFT JOIN reports r ON r.id = c.report_id
     WHERE c.citizen_id = $1 ${whereSql}
     ORDER BY c.created_at DESC LIMIT 100`,
    params,
  );
  ok(res, rows);
};

export const listCallbacksForOfficer = async (req, res) => {
  await sendDueCallbackReminders(req.user.id);
  const { rows } = await query(
    `SELECT c.*, u.full_name AS citizen_name, u.phone AS citizen_phone, r.title AS report_title
     FROM callback_requests c
     LEFT JOIN users u ON u.id = c.citizen_id
     LEFT JOIN reports r ON r.id = c.report_id
     WHERE c.officer_id = $1 ORDER BY c.created_at DESC LIMIT 100`,
    [req.user.id],
  );
  ok(res, rows);
};
