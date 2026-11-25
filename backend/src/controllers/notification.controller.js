import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { pushToUsers } from '../services/notification.service.js';
import { sendSms } from '../services/sms.service.js';

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

export const markContentUpdatesRead = async (req, res) => {
  const { rows } = await query(
    `UPDATE notifications SET is_read = true
     WHERE user_id = $1 AND is_read = false
       AND metadata->>'type' IN ('announcement', 'missing_person', 'wanted_person')
     RETURNING id`,
    [req.user.id],
  );
  ok(res, { count: rows.length }, 'Content update notifications cleared');
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

  let sms = null;
  if (delivery_type === 'sms') {
    const { rows } = await query(
      `SELECT phone FROM users WHERE id = ANY($1) AND phone IS NOT NULL AND phone != ''`,
      [targetIds],
    );
    const phones = rows.map((r) => r.phone);
    if (phones.length) {
      sms = await sendSms(phones, `[ZEGA-ALERT] ${title}\n${body}`);
    }
  } else {
    // Push/in-app broadcast. SMS is only used when the admin selects SMS.
    await pushToUsers(targetIds, title, body, metadata).catch(() => {});
  }

  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail)
     VALUES ($1, 'send_notification', 'notifications', NULL, $2)`,
    [req.user.id, JSON.stringify({ title, delivery_type, recipients: created.length, sms: sms?.status || null })],
  ).catch(() => {});

  ok(res, { count: created.length, sms: sms?.status || null }, 'Notifications dispatched', 201);
};

export const getUnreadCount = async (req, res) => {
  const { rows } = await query(
    `SELECT
       COUNT(*)::int AS count,
       COUNT(*) FILTER (WHERE metadata->>'type' = 'announcement')::int AS news_updates,
       COUNT(*) FILTER (
         WHERE metadata->>'type' IN ('missing_person', 'wanted_person')
       )::int AS person_updates
     FROM notifications
     WHERE user_id = $1 AND is_read = false`,
    [req.user.id],
  );
  ok(res, {
    count: rows[0]?.count || 0,
    newsUpdates: rows[0]?.news_updates || 0,
    personUpdates: rows[0]?.person_updates || 0,
  });
};
