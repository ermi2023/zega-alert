import { io } from './socket.js';
import { verifyToken } from '../utils/jwt.js';
import { query } from '../config/db.js';

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

    socket.on('chat:join', (conversationId) => {
      socket.join(`conversation:${conversationId}`);
    });

    socket.on('chat:send', async ({ conversationId, body, message_type = 'text', attachment_url }, ack) => {
      try {
        const { rows } = await query(
          `INSERT INTO messages (conversation_id, sender_id, body, message_type, attachment_url)
           VALUES ($1,$2,$3,$4,$5) RETURNING *`,
          [conversationId, socket.user.id, body || null, message_type, attachment_url || null],
        );
        const msg = rows[0];
        io.to(`conversation:${conversationId}`).emit('chat:message', msg);
        if (typeof ack === 'function') ack({ ok: true, msg });
      } catch (e) {
        if (typeof ack === 'function') ack({ ok: false, error: e.message });
      }
    });

    socket.on('sos:ack', async ({ sosId }) => {
      await query(
        `UPDATE sos_alerts SET status = 'acknowledged', dispatcher_id = $2 WHERE id = $1`,
        [sosId, socket.user.id],
      );
      io.to('staff').emit('sos:updated', { sosId, status: 'acknowledged', by: socket.user.full_name });
    });

    socket.on('disconnect', () => {});
  });
}
