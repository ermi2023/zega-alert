import { pool } from '../config/db.js';
import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { io } from '../socket/socket.js';
import { mirrorSet } from '../services/firebase.service.js';
import { findNearestPoliceStation, getStationStaffIds } from '../services/police-station.service.js';

export const createConversation = async (req, res) => {
  const { type = 'direct', title, participant_ids } = req.body;
  const ids = [...new Set([req.user.id, ...(participant_ids || [])])];
  if (ids.length < 2) return fail(res, 'A conversation needs at least 2 participants');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      'INSERT INTO conversations (type, title) VALUES ($1,$2) RETURNING *',
      [type, title || (type === 'group' ? 'Group chat' : null)],
    );
    for (const uid of ids) {
      await client.query(
        'INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1,$2)',
        [rows[0].id, uid],
      );
    }
    await client.query('COMMIT');
    ok(res, rows[0], 'Conversation created', 201);
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const createNearestStationConversation = async (req, res) => {
  const { latitude, longitude } = req.body;
  const station = await findNearestPoliceStation({ latitude, longitude });
  if (!station) {
    return fail(res, 'No active police station with a registered address and location is available nearby', 503);
  }
  const staffIds = await getStationStaffIds(station.id);
  if (!staffIds.length) {
    return fail(res, 'The nearest station has no active officers assigned yet. Please contact central dispatch.', 409);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    let conversationId;
    const existing = await client.query(
      `SELECT c.id FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id
       WHERE c.police_station_id = $1 AND cp.user_id = $2
       ORDER BY c.created_at DESC LIMIT 1`,
      [station.id, req.user.id],
    );
    if (existing.rows[0]) {
      conversationId = existing.rows[0].id;
      await client.query(
        `DELETE FROM conversation_participants cp
         USING users u
         WHERE cp.conversation_id = $1 AND cp.user_id = u.id
           AND cp.user_id <> $2 AND u.role = 'police'
           AND NOT (u.id = ANY($3::uuid[]))`,
        [conversationId, req.user.id, staffIds],
      );
    } else {
      const { rows } = await client.query(
        `INSERT INTO conversations (type, title, police_station_id)
         VALUES ('group', $1, $2) RETURNING id`,
        [station.name, station.id],
      );
      conversationId = rows[0].id;
    }

    for (const userId of [req.user.id, ...staffIds]) {
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [conversationId, userId],
      );
    }
    await client.query('COMMIT');
    ok(res, {
      id: conversationId,
      type: 'group',
      title: station.name,
      police_station_id: station.id,
      station_address: station.address_text,
    }, 'Station conversation ready', 201);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export const myConversations = async (req, res) => {
  const { rows } = await query(
    `SELECT c.*, json_agg(p.user_id ORDER BY p.user_id) AS participant_ids
     FROM conversations c
     JOIN conversation_participants p ON p.conversation_id = c.id
     WHERE p.user_id = $1
     GROUP BY c.id
     ORDER BY c.created_at DESC`,
    [req.user.id],
  );
  ok(res, rows);
};

export const getMessages = async (req, res) => {
  const isMember = await query(
    'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
    [req.params.id, req.user.id],
  );
  if (!isMember.rows.length) return fail(res, 'Not a participant', 403);
  const { rows } = await query(
    `SELECT m.*, u.full_name AS sender_name FROM messages m
     LEFT JOIN users u ON u.id = m.sender_id
     WHERE m.conversation_id = $1 ORDER BY m.created_at ASC`,
    [req.params.id],
  );
  await query(
    'UPDATE conversation_participants SET last_read_at = now() WHERE conversation_id = $1 AND user_id = $2',
    [req.params.id, req.user.id],
  );
  ok(res, rows);
};

export const sendMessage = async (req, res) => {
  const { body, message_type = 'text', attachment_url, attachment_type, latitude, longitude } = req.body;
  if (!body && message_type === 'text') return fail(res, 'message body required');
  const isMember = await query(
    'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
    [req.params.id, req.user.id],
  );
  if (!isMember.rows.length) return fail(res, 'Not a participant', 403);
  const { rows } = await query(
    `INSERT INTO messages (conversation_id, sender_id, body, message_type, attachment_url, attachment_type, latitude, longitude)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
    [req.params.id, req.user.id, body || null, message_type, attachment_url || null,
      attachment_type || null, latitude || null, longitude || null],
  );
  const msg = rows[0];
  const participants = await query(
    'SELECT user_id FROM conversation_participants WHERE conversation_id = $1',
    [req.params.id],
  );
  for (const p of participants.rows) {
    io.to(`user:${p.user_id}`).emit('chat:message', msg);
  }
  mirrorSet('chat_messages', msg.id, msg).catch(() => {});
  ok(res, msg, 'Sent', 201);
};

export const listMessagesForAdmin = async (req, res) => {
  const { rows } = await query('SELECT * FROM messages ORDER BY created_at DESC LIMIT 50');
  ok(res, rows);
};

// Estimated queue wait time based on citizens waiting for a staff reply (doc 4.3.5).
export const getEstimatedWait = async (req, res) => {
  const { rows } = await query(
    `SELECT COUNT(DISTINCT c.id)::int AS waiting
     FROM conversations c
     WHERE c.created_at > now() - interval '15 minutes'
       AND NOT EXISTS (
         SELECT 1 FROM messages m JOIN users u ON u.id = m.sender_id
         WHERE m.conversation_id = c.id AND u.role <> 'citizen'
       )`,
  );
  const waiting = rows[0].waiting || 0;
  const estimated = waiting === 0 ? 0 : Math.min(30, waiting * 3);
  ok(res, { waiting, estimated_wait_minutes: estimated });
};

// Post-conversation satisfaction rating (doc 4.3.5).
export const rateConversation = async (req, res) => {
  const { rating, comment } = req.body;
  const ratingNum = parseInt(rating, 10);
  if (!ratingNum || ratingNum < 1 || ratingNum > 5) return fail(res, 'rating must be 1-5');
  const isMember = await query(
    'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
    [req.params.id, req.user.id],
  );
  if (!isMember.rows.length) return fail(res, 'Not a participant', 403);
  const { rows } = await query(
    `INSERT INTO chat_ratings (conversation_id, user_id, rating, comment)
     VALUES ($1,$2,$3,$4)
     ON CONFLICT (conversation_id, user_id)
     DO UPDATE SET rating = EXCLUDED.rating, comment = EXCLUDED.comment, created_at = now()
     RETURNING *`,
    [req.params.id, req.user.id, ratingNum, comment || null],
  );
  ok(res, rows[0], 'Thanks for your feedback');
};

export const getUnreadCount = async (req, res) => {
  const { rows } = await query(
    `SELECT COUNT(*)::int AS count
     FROM messages m
     JOIN conversation_participants p ON p.conversation_id = m.conversation_id
     WHERE p.user_id = $1
       AND m.sender_id IS DISTINCT FROM $1
       AND (p.last_read_at IS NULL OR m.created_at > p.last_read_at)`,
    [req.user.id],
  );
  ok(res, { count: rows[0]?.count || 0 });
};

export const markConversationRead = async (req, res) => {
  await query(
    `UPDATE conversation_participants SET last_read_at = now()
     WHERE conversation_id = $1 AND user_id = $2`,
    [req.params.id, req.user.id],
  );
  ok(res, null, 'Conversation marked read');
};
