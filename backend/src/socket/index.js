import { io } from './socket.js';
import { verifyToken } from '../utils/jwt.js';
import { query } from '../config/db.js';
import { endLiveStreamsForUser } from '../controllers/sos-live.controller.js';
import { getRouteRecipients } from '../services/police-station.service.js';

export function setupSocket() {
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error('Authentication required'));
      const payload = verifyToken(token);
      const { rows } = await query('SELECT id, role, full_name FROM users WHERE id = $1', [payload.sub]);
      if (!rows[0]) return next(new Error('Unknown user'));
      socket.user = rows[0];
      next();
    } catch (e) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.user.id}`);
    const { role } = socket.user;
    if (['police', 'dispatcher', 'regional_admin', 'system_admin'].includes(role)) {
      socket.join('staff');
    }
    socket.join('citizens');

    const joinConversationIfMember = async (conversationId) => {
      if (typeof conversationId !== 'string') return;
      try {
        const { rows } = await query(
          `SELECT 1 FROM conversation_participants
           WHERE conversation_id = $1 AND user_id = $2`,
          [conversationId, socket.user.id],
        );
        if (rows.length) socket.join(`conversation:${conversationId}`);
      } catch (error) {
        console.error('[SOCKET CHAT JOIN]', error.message);
      }
    };

    socket.on('chat:join', joinConversationIfMember);

    const joinSosIfRecipient = async (sosId) => {
      if (typeof sosId !== 'string') return;
      try {
        const { rows } = await query(
          'SELECT user_id, station_id FROM sos_alerts WHERE id = $1',
          [sosId],
        );
        if (!rows[0]) return;
        if (rows[0].user_id === socket.user.id) {
          socket.join(`sos:${sosId}`);
          return;
        }
        const recipients = await getRouteRecipients(rows[0].station_id);
        if (recipients.userIds.includes(socket.user.id)) {
          socket.join(`sos:${sosId}`);
        }
      } catch (error) {
        console.error('[SOCKET SOS JOIN]', error.message);
      }
    };

    socket.on('join', (room) => {
      if (typeof room !== 'string') return;
      if (room.startsWith('sos:')) {
        void joinSosIfRecipient(room.slice(4));
      } else if (room.startsWith('conversation:')) {
        void joinConversationIfMember(room.slice(13));
      }
    });

    socket.on('chat:send', async ({ conversationId, body, message_type = 'text', attachment_url, attachment_type }, ack) => {
      try {
        // Membership check: only conversation participants may send.
        const { rows: part } = await query(
          `SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2`,
          [conversationId, socket.user.id],
        );
        if (part.length === 0) {
          if (typeof ack === 'function') ack({ ok: false, error: 'Not a participant of this conversation' });
          return;
        }
        const { rows } = await query(
          `INSERT INTO messages (conversation_id, sender_id, body, message_type, attachment_url, attachment_type)
           VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
          [conversationId, socket.user.id, body || null, message_type, attachment_url || null,
            attachment_type || null],
        );
        const msg = rows[0];
        io.to(`conversation:${conversationId}`).emit('chat:message', msg);
        if (typeof ack === 'function') ack({ ok: true, msg });
      } catch (e) {
        if (typeof ack === 'function') ack({ ok: false, error: e.message });
      }
    });

    socket.on('sos:ack', async ({ sosId }) => {
      const { rows } = await query(
        'SELECT station_id FROM sos_alerts WHERE id = $1',
        [sosId],
      );
      if (!rows[0]) return;
      const recipients = await getRouteRecipients(rows[0].station_id);
      if (!recipients.userIds.includes(socket.user.id)) return;
      await query(
        `UPDATE sos_alerts SET status = 'acknowledged', dispatcher_id = $2 WHERE id = $1`,
        [sosId, socket.user.id],
      );
      for (const userId of recipients.userIds) {
        io.to(`user:${userId}`).emit('sos:updated', {
          sosId,
          status: 'acknowledged',
          by: socket.user.full_name,
        });
      }
    });

    socket.on('disconnect', () => {
      endLiveStreamsForUser(socket.user.id);
    });
  });
}
