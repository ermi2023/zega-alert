import { query } from '../config/db.js';
import { io } from '../socket/socket.js';
import { sendNotificationSms } from './sms.service.js';
import { firebaseEnabled, firebaseMessaging, mirrorSet } from './firebase.service.js';

export async function notifyStaff(event, data, dispatch = {}) {
  const { rows } = await query(
    `SELECT DISTINCT u.id FROM users u
     WHERE u.role IN ('police','dispatcher','regional_admin','system_admin')
       AND u.is_active = true
       AND ($1::text IS NULL OR u.region = $1 OR u.region IS NULL)`,
    [data.region || null],
  );
  for (const staffUser of rows) {
    io.to(`user:${staffUser.id}`).emit(event, { ...data, dispatch });
  }
}

export async function notifyUser(userId, event, data) {
  io.to(`user:${userId}`).emit(event, data);
}

export async function sendFcmPush(token, title, body, data = {}) {
  if (!token) return { ok: false, reason: 'no_token' };

  if (!firebaseEnabled()) {
    console.log(`[FCM DEV] Push to ${token.slice(0, 12)}… — ${title}: ${body}`);
    return { ok: true, dev: true };
  }

  const stringData = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]));
  try {
    const messageId = await firebaseMessaging().send({
      token,
      notification: { title, body },
      data: stringData,
      android: { priority: 'high' },
      apns: { headers: { 'apns-priority': '10' } },
    });
    // Hybrid store: keep a Firestore audit trail of delivered pushes.
    mirrorSet('notifications', messageId, { token, title, body, ...stringData }).catch(() => {});
    return { ok: true, messageId };
  } catch (err) {
    console.error('[FCM ERROR]', err.message);
    return { ok: false, error: err.message };
  }
}

export async function pushToDevice(user, payload) {
  if (!user.device_token) return { ok: false, reason: 'no_token' };
  return sendFcmPush(
    user.device_token,
    payload.title || 'ZEGA-ALERT',
    payload.body || '',
    payload.data || {},
  );
}

export async function pushToUsers(userIds, title, body, data = {}) {
  if (!userIds.length) return [];
  const { rows } = await query(
    `SELECT id, device_token FROM users WHERE id = ANY($1) AND device_token IS NOT NULL AND device_token != ''`,
    [userIds],
  );
  const results = await Promise.allSettled(
    rows.map((u) => sendFcmPush(u.device_token, title, body, data)),
  );
  return results.map((r) => (r.status === 'fulfilled' ? r.value : { ok: false, error: r.reason?.message }));
}

export async function notifyPublishedContent({ type, id, label }) {
  const contentLabel = {
    announcement: 'item',
    missing_person: 'missing person',
    wanted_person: 'wanted person',
  }[type] || 'item';
  const title = 'New data published';
  const body = `1 new ${contentLabel} published: ${label}`;
  const metadata = { type, contentId: id, newCount: 1 };

  try {
    const { rows } = await query(
      `INSERT INTO notifications (user_id, title, body, delivery_type, metadata)
       SELECT id, $1, $2, 'push', $3::jsonb
       FROM users WHERE is_active = true
       RETURNING user_id`,
      [title, body, JSON.stringify(metadata)],
    );
    const deliveries = await pushToUsers(
      rows.map((row) => row.user_id),
      title,
      body,
      metadata,
    );
    const failedDeliveries = deliveries.filter((delivery) => !delivery.ok).length;
    if (failedDeliveries > 0) {
      console.error(`[PUBLICATION NOTIFICATION] ${failedDeliveries} push delivery(s) failed`);
    }
  } catch (error) {
    console.error('[PUBLICATION NOTIFICATION ERROR]', error);
  }
}

export async function notifyUserWithFallback(userId, title, body) {
  const { rows } = await query('SELECT device_token, phone FROM users WHERE id = $1', [userId]);
  const user = rows[0];
  if (!user) return;

  if (user.device_token) {
    await pushToDevice(user, { title, body });
  }
  // Always send SMS as fallback for critical messages
  if (user.phone) {
    await sendNotificationSms(user.phone, title, body);
  }
}
