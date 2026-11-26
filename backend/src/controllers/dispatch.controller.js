import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { io } from '../socket/socket.js';
import { haversine } from '../services/dispatch.service.js';
import { getRecentPositions } from './position.controller.js';
import { getRouteRecipients } from '../services/police-station.service.js';

const ASSUMED_SPEED_MPS = 11.1;

export const assignUnits = async (req, res) => {
  const { sosId } = req.params;
  const { officer_ids, notes } = req.body;

  if (!officer_ids || !Array.isArray(officer_ids) || !officer_ids.length) {
    return fail(res, 'officer_ids array is required');
  }

  const { rows: sos } = await query(
    'SELECT id, status, latitude, longitude, station_id FROM sos_alerts WHERE id = $1',
    [sosId],
  );
  if (!sos[0]) return fail(res, 'SOS not found', 404);
  const recipients = await getRouteRecipients(sos[0].station_id);
  if (
    req.user.role === 'dispatcher' &&
    !recipients.userIds.includes(req.user.id)
  ) {
    return fail(res, 'This SOS is routed to another station', 403);
  }
  const allowedIds = new Set(recipients.userIds);
  if (officer_ids.some((officerId) => !allowedIds.has(officerId))) {
    return fail(res, 'Assign this SOS only to the nearest station or central dispatch', 403);
  }

  const positions = getRecentPositions();
  const assignments = [];
  for (const officerId of officer_ids) {
    const { rows: existing } = await query(
      'SELECT id FROM dispatch_assignments WHERE sos_id = $1 AND assigned_to = $2',
      [sosId, officerId],
    );
    if (existing.length > 0) continue;

    const pos = positions.get(officerId);
    const distance_m = (pos && sos[0].latitude != null && sos[0].longitude != null)
      ? haversine(sos[0].latitude, sos[0].longitude, pos.latitude, pos.longitude)
      : null;
    const eta_seconds = distance_m != null ? Math.round(distance_m / ASSUMED_SPEED_MPS) : null;

    const { rows } = await query(
      `INSERT INTO dispatch_assignments (sos_id, assigned_to, assigned_by, notes, distance_m, eta_seconds)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [sosId, officerId, req.user.id, notes || 'Assigned by dispatcher', distance_m, eta_seconds],
    );

    const { rows: officer } = await query('SELECT full_name, role FROM users WHERE id = $1', [officerId]);
    assignments.push({
      ...rows[0],
      officer_name: officer[0]?.full_name,
      officer_role: officer[0]?.role,
      distance_m,
      eta_seconds,
    });

    io.to(`user:${officerId}`).emit('dispatch:assigned', {
      sosId,
      assignmentId: rows[0].id,
      assignedBy: req.user.full_name,
      etaSeconds: eta_seconds,
    });
  }

  const { rows: allAssignments } = await query(
    'SELECT COUNT(*) as count FROM dispatch_assignments WHERE sos_id = $1',
    [sosId],
  );
  await query(
    `UPDATE sos_alerts SET status = CASE WHEN $2 > 0 THEN 'dispatched'::sos_status ELSE status END WHERE id = $1`,
    [sosId, parseInt(allAssignments[0].count)],
  );

  io.to(`sos:${sosId}`).emit('dispatch:updated', { sosId });

  ok(res, { assignments, totalAssigned: parseInt(allAssignments[0].count) }, `${assignments.length} unit(s) assigned`);
};

export const removeUnit = async (req, res) => {
  const { sosId, assignmentId } = req.params;

  const { rows: assignment } = await query(
    `SELECT da.assigned_to, s.station_id
     FROM dispatch_assignments da JOIN sos_alerts s ON s.id = da.sos_id
     WHERE da.id = $1 AND da.sos_id = $2`,
    [assignmentId, sosId],
  );
  if (!assignment[0]) return fail(res, 'Assignment not found', 404);
  const recipients = await getRouteRecipients(assignment[0].station_id);
  if (
    !recipients.userIds.includes(assignment[0].assigned_to) ||
    (req.user.role === 'dispatcher' && !recipients.userIds.includes(req.user.id))
  ) {
    return fail(res, 'This assignment is no longer routed to the nearest station or central dispatch', 403);
  }

  await query('DELETE FROM dispatch_assignments WHERE id = $1', [assignmentId]);

  io.to(`user:${assignment[0].assigned_to}`).emit('dispatch:removed', { sosId });
  io.to(`sos:${sosId}`).emit('dispatch:updated', { sosId });

  ok(res, null, 'Unit removed');
};

export const listAssignedUnits = async (req, res) => {
  const { sosId } = req.params;
  const { rows: sos } = await query('SELECT station_id FROM sos_alerts WHERE id = $1', [sosId]);
  if (!sos[0]) return fail(res, 'SOS not found', 404);
  const recipients = await getRouteRecipients(sos[0].station_id);
  if (
    req.user.role === 'dispatcher' &&
    !recipients.userIds.includes(req.user.id)
  ) {
    return fail(res, 'This SOS is routed to another station', 403);
  }
  const { rows } = await query(
    `SELECT da.*, u.full_name AS officer_name, u.role AS officer_role,
            u.region, u.sub_city
     FROM dispatch_assignments da
     LEFT JOIN users u ON u.id = da.assigned_to
     WHERE da.sos_id = $1 AND da.assigned_to = ANY($2::uuid[])
     ORDER BY da.created_at ASC`,
    [sosId, recipients.userIds],
  );
  ok(res, rows);
};

export const updateUnitStatus = async (req, res) => {
  const { sosId, assignmentId } = req.params;
  const { status, notes } = req.body;

  const valid = ['assigned', 'en_route', 'on_scene', 'completed'];
  if (!valid.includes(status)) return fail(res, `status must be one of ${valid.join(', ')}`);

  const { rows: existing } = await query(
    `SELECT da.assigned_to, s.station_id
     FROM dispatch_assignments da JOIN sos_alerts s ON s.id = da.sos_id
     WHERE da.id = $1 AND da.sos_id = $2`,
    [assignmentId, sosId],
  );
  if (!existing[0]) return fail(res, 'Assignment not found', 404);
  const recipients = await getRouteRecipients(existing[0].station_id);
  if (
    !recipients.userIds.includes(existing[0].assigned_to) ||
    (req.user.role === 'dispatcher' && !recipients.userIds.includes(req.user.id))
  ) {
    return fail(res, 'This assignment is not available to your dispatch route', 403);
  }

  const { rows } = await query(
    `UPDATE dispatch_assignments
     SET status = $1, notes = COALESCE($2, notes),
         completed_at = CASE WHEN $1 = 'completed' THEN now() ELSE completed_at END
     WHERE id = $3 AND sos_id = $4
     RETURNING *`,
    [status, notes || null, assignmentId, sosId],
  );
  if (!rows[0]) return fail(res, 'Assignment not found', 404);

  const { rows: sos } = await query('SELECT user_id FROM sos_alerts WHERE id = $1', [sosId]);
  if (sos[0]?.user_id) {
    const { rows: officer } = await query('SELECT full_name FROM users WHERE id = $1', [rows[0].assigned_to]);
    io.to(`user:${sos[0].user_id}`).emit('dispatch:status', {
      sosId,
      officerName: officer[0]?.full_name || 'Officer',
      status,
    });
  }

  io.to(`sos:${sosId}`).emit('dispatch:updated', { sosId });

  ok(res, rows[0], 'Status updated');
};
