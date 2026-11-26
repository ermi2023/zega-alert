import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { io } from '../socket/socket.js';
import { dispatchSos } from '../services/dispatch.service.js';
import {
  findNearestPoliceStation,
  notifyNearestStationOrCentral,
} from '../services/police-station.service.js';

const officerPositions = new Map();

export const reportPosition = async (req, res) => {
  const { latitude, longitude, heading, speed } = req.body;
  if (latitude == null || longitude == null) {
    return fail(res, 'latitude and longitude are required');
  }

  if (!['police', 'dispatcher'].includes(req.user.role)) {
    return fail(res, 'Only officers can report positions', 403);
  }

  const position = {
    userId: req.user.id,
    userName: req.user.full_name || 'Officer',
    role: req.user.role,
    latitude,
    longitude,
    heading: heading || null,
    speed: speed || null,
    timestamp: Date.now(),
  };

  officerPositions.set(req.user.id, position);

  await query(
    `INSERT INTO audit_log (user_id, action, entity, detail)
     VALUES ($1, 'report_position', 'users', $2)`,
    [req.user.id, JSON.stringify({ latitude, longitude, heading, speed })],
  );

  io.emit('officer:position', position);

  ok(res, position, 'Position updated');
};

// Citizens stream their live location while an SOS is active (doc SD-4 steps 10-11).
export const reportSosLocation = async (req, res) => {
  const { sosId, latitude, longitude } = req.body;
  if (!sosId || latitude == null || longitude == null) {
    return fail(res, 'sosId, latitude and longitude are required');
  }
  const { rows } = await query(
    'SELECT id, user_id, status, station_id FROM sos_alerts WHERE id = $1',
    [sosId],
  );
  if (!rows[0]) return fail(res, 'SOS not found', 404);
  if (rows[0].user_id !== req.user.id) return fail(res, 'Not your SOS alert', 403);
  if (['resolved', 'cancelled'].includes(rows[0].status)) {
    return fail(res, 'SOS is no longer active', 409);
  }
  let alert = rows[0];
  if (!alert.station_id) {
    const station = await findNearestPoliceStation({ latitude, longitude });
    if (station) {
      const { rows: updated } = await query(
        `UPDATE sos_alerts SET latitude = $1, longitude = $2, station_id = $3
         WHERE id = $4 AND station_id IS NULL RETURNING id, user_id, status, station_id`,
        [latitude, longitude, station.id, sosId],
      );
      if (updated[0]) {
        alert = updated[0];
        const dispatch = await dispatchSos({
          ...alert,
          latitude,
          longitude,
        });
        const recipients = await notifyNearestStationOrCentral('sos:new', {
          ...alert,
          latitude,
          longitude,
          station_name: station.name,
          station_address: station.address_text,
        }, dispatch);
        io.to(`user:${alert.user_id}`).emit('sos:status', {
          sosId,
          status: dispatch.assignments.length ? 'dispatched' : 'triggered',
          response_notes: recipients.userIds.length === 0
            ? 'No station officers or central dispatch recipients are currently available'
            : recipients.route === 'nearest_station'
              ? `SOS routed to ${station.name}`
              : 'SOS remains with central dispatch because no station officers are assigned',
        });
      } else {
        const { rows: latest } = await query(
          'SELECT id, user_id, status, station_id FROM sos_alerts WHERE id = $1',
          [sosId],
        );
        alert = latest[0] || alert;
      }
    } else {
      await query(
        'UPDATE sos_alerts SET latitude = $1, longitude = $2 WHERE id = $3',
        [latitude, longitude, sosId],
      );
    }
  } else {
    await query(
      'UPDATE sos_alerts SET latitude = $1, longitude = $2 WHERE id = $3',
      [latitude, longitude, sosId],
    );
  }
  const payload = {
    sosId,
    userId: req.user.id,
    latitude,
    longitude,
    timestamp: Date.now(),
  };
  io.to(`sos:${sosId}`).emit('sos:location', payload);
  await notifyNearestStationOrCentral('sos:location', {
    ...payload,
    station_id: alert.station_id,
  });
  ok(res, payload, 'Location updated');
};

export const getRecentPositions = (maxAgeMs = 10 * 60 * 1000) => {
  const cutoff = Date.now() - maxAgeMs;
  const fresh = new Map();
  for (const [id, p] of officerPositions) {
    if (p.timestamp > cutoff) fresh.set(id, p);
  }
  return fresh;
};

export const getOfficerPositions = async (req, res) => {
  const { region } = req.query;

  let positions = Array.from(officerPositions.values());

  if (region) {
    const { rows: officers } = await query(
      `SELECT id FROM users WHERE role IN ('police','dispatcher') AND region = $1 AND is_active = true`,
      [region],
    );
    const officerIds = new Set(officers.map(o => o.id));
    positions = positions.filter(p => officerIds.has(p.userId));
  }

  const fiveMinAgo = Date.now() - 5 * 60 * 1000;
  positions = positions.filter(p => p.timestamp > fiveMinAgo);

  ok(res, positions);
};
