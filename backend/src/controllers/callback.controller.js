import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { isUuid } from '../utils/uuid.js';
import { io } from '../socket/socket.js';

const MODES = ['voice', 'video', 'chat'];

export const requestCallback = async (req, res) => {
  const { report_id, citizen_id, requested_slot, mode = 'voice', notes } = req.body;
  if (!report_id || !citizen_id) return fail(res, 'report_id and citizen_id required');
  if (!isUuid(report_id) || !isUuid(citizen_id)) return fail(res, 'Invalid id format', 400);
  if (!MODES.includes(mode)) return fail(res, `mode must be one of ${MODES.join(', ')}`);
  const citizen = await query('SELECT id, full_name, role FROM users WHERE id = $1', [citizen_id]);
  if (!citizen.rows[0] || citizen.rows[0].role !== 'citizen') return fail(res, 'citizen not found', 404);
  const { rows } = await query(
    `INSERT INTO callback_requests (report_id, citizen_id, officer_id, requested_slot, mode, notes)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [report_id, citizen_id, req.user.id, requested_slot || null, mode, notes || null],
  );
  io.to(`user:${citizen_id}`).emit('callback:new', rows[0]);
  ok(res, rows[0], 'Callback requested', 201);
};

export const respondToCallback = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid callback id', 400);
  const { status } = req.body;
  if (!['accepted', 'declined', 'completed'].includes(status)) {
    return fail(res, 'status must be accepted, declined or completed');
  }
  const { rows } = await query(
    `UPDATE callback_requests SET status = $1, responded_at = now()
     WHERE id = $2 AND citizen_id = $3
     RETURNING *`,
    [status, req.params.id, req.user.id],
  );
  if (!rows[0]) return fail(res, 'Callback not found or not for you', 404);
  io.to(`user:${rows[0].officer_id}`).emit('callback:update', rows[0]);
  ok(res, rows[0], `Callback ${status}`);
};

export const listCallbacks = async (req, res) => {
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
