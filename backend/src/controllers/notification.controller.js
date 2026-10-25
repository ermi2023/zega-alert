import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { sendFcmPush, pushToUsers } from '../services/notification.service.js';

export const listNotifications = async (req, res) => {
  const { limit = 30, page = 1 } = req.query;
  const offset = (parseInt(page, 10) - 1) * parseInt(limit, 10);
  const { rows } = await query(
    `SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [req.user.id, parseInt(limit, 10), offset],
  );
  const unreadCount = await query(
    `SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND is_read = false`,
    [req.user.id],
  );
  ok(res, { notifications: rows, unread: unreadCount.rows[0]?.count || 0 });
};

export const markRead = async (req, res) => {
  const { id } = req.params;
  const { rows } = await query(
    `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING *`,
    [id, req.user.id],
  );
  if (!rows[0]) return fail(res, 'Notification not found', 404);
  ok(res, rows[0], 'Marked as read');
};

export const markAllRead = async (req, res) => {
  await query(
    `UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`,
    [req.user.id],
  );
  ok(res, null, 'All notifications marked as read');
};

export const sendNotification = async (req, res) => {
  const { user_ids, title, body, delivery_type = 'push', metadata = {} } = req.body;
  if (!title || !body) return fail(res, 'title and body required');

  let targetIds = user_ids;
  if (!targetIds || !targetIds.length) {
    // If not specified, broadcast to active users
    const { rows } = await query(`SELECT id FROM users WHERE is_active = true`);
    targetIds = rows.map((r) => r.id);
  }

  const created = [];
  for (const uid of targetIds) {
    const { rows } = await query(
      `INSERT INTO notifications (user_id, title, body, delivery_type, metadata)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [uid, title, body, delivery_type, JSON.stringify(metadata)],
    );
    created.push(rows[0]);
  }

  // Push FCM
  pushToUsers(targetIds, title, body, metadata).catch(() => {});

  ok(res, { count: created.length }, 'Notifications dispatched', 201);
};
