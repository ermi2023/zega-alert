import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

const ENTITY_TABLES = {
  announcement: 'announcements',
  missing_person: 'missing_persons',
  wanted_person: 'wanted_persons',
};
const ENTITY_OWNER_COLUMNS = {
  announcement: 'author_id',
  missing_person: 'reporter_id',
  wanted_person: null,
};
const STAFF_ROLES = new Set(['police', 'dispatcher', 'regional_admin', 'system_admin']);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const resolveEntity = async (req, res) => {
  const entityType = String(req.params.entityType || '');
  const entityId = String(req.params.entityId || '');
  if (!Object.prototype.hasOwnProperty.call(ENTITY_TABLES, entityType)) {
    fail(res, 'Invalid entity type', 400);
    return null;
  }
  if (!UUID_RE.test(entityId)) {
    fail(res, 'Invalid entity id', 400);
    return null;
  }
  const ownerColumn = ENTITY_OWNER_COLUMNS[entityType];
  const columns = ownerColumn ? `id, ${ownerColumn} AS owner_id` : 'id';
  const { rows } = await query(
    `SELECT ${columns} FROM ${ENTITY_TABLES[entityType]} WHERE id = $1`,
    [entityId],
  );
  if (!rows[0]) {
    fail(res, 'Entity not found', 404);
    return null;
  }
  return { entityType, entityId, ownerId: rows[0].owner_id || null };
};

const canManagePhotos = (req, ctx, res) => {
  const isStaff = Boolean(req.user && STAFF_ROLES.has(req.user.role));
  const isOwner = Boolean(req.user && ctx.ownerId && String(ctx.ownerId) === String(req.user.id));
  if (!isStaff && !isOwner) {
    fail(res, 'Forbidden: staff role or ownership required', 403);
    return false;
  }
  return true;
};

// Toggle reaction: like or dislike
export const toggleLike = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  const { entityType, entityId } = ctx;
  const reactionType = req.body.reaction === 'dislike' ? 'dislike' : 'like';
  const userId = req.user.id;

  // Check if reaction exists
  const existing = await query(
    'SELECT id, reaction FROM post_likes WHERE user_id = $1 AND entity_type = $2 AND entity_id = $3',
    [userId, entityType, entityId]
  );

  let userReaction = null;
  if (existing.rows.length > 0) {
    const currentReaction = existing.rows[0].reaction || 'like';
    if (currentReaction === reactionType) {
      // Toggle off if same reaction clicked
      await query('DELETE FROM post_likes WHERE id = $1', [existing.rows[0].id]);
      userReaction = null;
    } else {
      // Switch reaction (e.g. from dislike to like, or like to dislike)
      await query('UPDATE post_likes SET reaction = $1 WHERE id = $2', [reactionType, existing.rows[0].id]);
      userReaction = reactionType;
    }
  } else {
    await query(
      'INSERT INTO post_likes (user_id, entity_type, entity_id, reaction) VALUES ($1, $2, $3, $4)',
      [userId, entityType, entityId, reactionType]
    );
    userReaction = reactionType;
  }

  const counts = await query(
    `SELECT 
       COUNT(*) FILTER (WHERE reaction = 'like' OR reaction IS NULL)::int AS like_count,
       COUNT(*) FILTER (WHERE reaction = 'dislike')::int AS dislike_count
     FROM post_likes WHERE entity_type = $1 AND entity_id = $2`,
    [entityType, entityId]
  );

  ok(res, {
    liked: userReaction === 'like',
    disliked: userReaction === 'dislike',
    user_reaction: userReaction,
    like_count: counts.rows[0].like_count,
    dislike_count: counts.rows[0].dislike_count,
  });
};

// Get likes summary and list
export const getLikes = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  const { entityType, entityId } = ctx;
  const userId = req.user?.id || null;

  const counts = await query(
    `SELECT 
       COUNT(*) FILTER (WHERE reaction = 'like' OR reaction IS NULL)::int AS like_count,
       COUNT(*) FILTER (WHERE reaction = 'dislike')::int AS dislike_count
     FROM post_likes WHERE entity_type = $1 AND entity_id = $2`,
    [entityType, entityId]
  );

  let userReaction = null;
  if (userId) {
    const userLikeResult = await query(
      'SELECT reaction FROM post_likes WHERE user_id = $1 AND entity_type = $2 AND entity_id = $3',
      [userId, entityType, entityId]
    );
    if (userLikeResult.rows.length > 0) {
      userReaction = userLikeResult.rows[0].reaction || 'like';
    }
  }

  ok(res, {
    like_count: counts.rows[0].like_count,
    dislike_count: counts.rows[0].dislike_count,
    user_reaction: userReaction,
    user_liked: userReaction === 'like',
    user_disliked: userReaction === 'dislike',
  });
};

// Add comment
export const addComment = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  const { entityType, entityId } = ctx;
  const { body } = req.body;
  const userId = req.user.id;

  if (!body || !body.trim()) {
    return fail(res, 'Comment text cannot be empty');
  }

  const { rows } = await query(
    `INSERT INTO post_comments (user_id, entity_type, entity_id, body)
     VALUES ($1, $2, $3, $4)
     RETURNING id, user_id, entity_type, entity_id, body, created_at`,
    [userId, entityType, entityId, body.trim()]
  );

  const comment = rows[0];
  comment.user_name = req.user.full_name || 'Anonymous';
  comment.user_role = req.user.role || 'citizen';

  const countResult = await query(
    'SELECT COUNT(*)::int AS count FROM post_comments WHERE entity_type = $1 AND entity_id = $2',
    [entityType, entityId]
  );

  ok(res, {
    comment,
    comment_count: countResult.rows[0].count,
  }, 'Comment posted', 201);
};

// Get comments for entity
export const getComments = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  const { entityType, entityId } = ctx;

  const { rows } = await query(
    `SELECT c.id, c.user_id, c.entity_type, c.entity_id, c.body, c.created_at,
            COALESCE(u.full_name, 'Citizen') AS user_name,
            COALESCE(u.role, 'citizen') AS user_role
     FROM post_comments c
     LEFT JOIN users u ON u.id = c.user_id
     WHERE c.entity_type = $1 AND c.entity_id = $2
     ORDER BY c.created_at ASC`,
    [entityType, entityId]
  );

  ok(res, rows);
};

// Get combined social counts (likes + comments)
export const getSocialCounts = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  const { entityType, entityId } = ctx;
  const userId = req.query.user_id || req.user?.id || null;

  const likeCountRes = await query(
    'SELECT COUNT(*)::int AS count FROM post_likes WHERE entity_type = $1 AND entity_id = $2',
    [entityType, entityId]
  );

  const commentCountRes = await query(
    'SELECT COUNT(*)::int AS count FROM post_comments WHERE entity_type = $1 AND entity_id = $2',
    [entityType, entityId]
  );

  let userLiked = false;
  if (userId) {
    const userLikeResult = await query(
      'SELECT id FROM post_likes WHERE user_id = $1 AND entity_type = $2 AND entity_id = $3',
      [userId, entityType, entityId]
    );
    userLiked = userLikeResult.rows.length > 0;
  }

  ok(res, {
    like_count: likeCountRes.rows[0].count,
    comment_count: commentCountRes.rows[0].count,
    user_liked: userLiked,
  });
};

// Add multiple photos
export const addPhotos = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  if (!canManagePhotos(req, ctx, res)) return;
  const { entityType, entityId } = ctx;
  const { photos } = req.body;

  const photoList = Array.isArray(photos) ? photos : (req.body.photo_url ? [req.body.photo_url] : []);
  if (photoList.length === 0) {
    return fail(res, 'No photos provided');
  }

  const inserted = [];
  for (let i = 0; i < photoList.length; i++) {
    const { rows } = await query(
      `INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [entityType, entityId, photoList[i], i]
    );
    inserted.push(rows[0]);
  }

  ok(res, inserted, 'Photos added', 201);
};

// Get photos for entity
export const getPhotos = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  if (!canManagePhotos(req, ctx, res)) return;
  const { entityType, entityId } = ctx;

  const { rows } = await query(
    `SELECT photo_url FROM person_photos
     WHERE entity_type = $1 AND entity_id = $2
     ORDER BY sort_order ASC, created_at ASC`,
    [entityType, entityId]
  );

  ok(res, rows.map(r => r.photo_url));
};

export const deletePhotos = async (req, res) => {
  const ctx = await resolveEntity(req, res);
  if (!ctx) return;
  if (!canManagePhotos(req, ctx, res)) return;
  const { entityType, entityId } = ctx;

  const { rowCount } = await query(
    'DELETE FROM person_photos WHERE entity_type = $1 AND entity_id = $2',
    [entityType, entityId]
  );
  ok(res, { deleted: rowCount }, 'Photos deleted');
};
