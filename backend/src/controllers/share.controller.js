import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

const PLATFORMS = ['facebook', 'telegram', 'twitter', 'instagram', 'whatsapp', 'copy_link', 'other'];

/**
 * UC-11: record the analytics event (platform, content type, timestamp) when
 * a citizen shares content to a social media platform.
 */
export const recordShare = async (req, res) => {
  const { content_type, content_id, platform } = req.body;
  if (!content_type || !platform) return fail(res, 'content_type and platform are required');
  if (!PLATFORMS.includes(platform)) {
    return fail(res, `platform must be one of: ${PLATFORMS.join(', ')}`);
  }
  const { rows } = await query(
    `INSERT INTO share_events (user_id, content_type, content_id, platform)
     VALUES ($1,$2,$3,$4) RETURNING *`,
    [req.user.id, content_type, content_id || null, platform],
  );
  ok(res, rows[0], 'Share recorded', 201);
};

export const shareStats = async (req, res) => {
  const [byPlatform, byType, total] = await Promise.all([
    query('SELECT platform, COUNT(*)::int AS n FROM share_events GROUP BY platform ORDER BY n DESC'),
    query('SELECT content_type, COUNT(*)::int AS n FROM share_events GROUP BY content_type ORDER BY n DESC'),
    query('SELECT COUNT(*)::int AS total FROM share_events'),
  ]);
  ok(res, { total: total.rows[0].total, byPlatform: byPlatform.rows, byContentType: byType.rows });
};

export const listPlatforms = async (req, res) => ok(res, PLATFORMS);
