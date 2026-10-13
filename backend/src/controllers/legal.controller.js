import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { mirrorSet, mirrorDelete } from '../services/firebase.service.js';

const REVIEW_STATUSES = ['published', 'under_review', 'draft'];

const writeHistory = (legalId, action, fromStatus, toStatus, note, userId) =>
  query(
    `INSERT INTO legal_review_history (legal_id, action, from_status, to_status, note, changed_by)
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [legalId, action, fromStatus || null, toStatus || null, note || null, userId || null],
  );

export const listLegal = async (req, res) => {
  const { category, language, review_status } = req.query;
  const isStaff = ['system_admin', 'regional_admin'].includes(req.user?.role);
  const includeAll = req.query.include_all === 'true' && isStaff;
  const params = [];
  const where = [];
  if (!includeAll) { where.push(`is_published = true`); where.push(`review_status = 'published'`); }
  if (review_status) { params.push(review_status); where.push(`review_status = $${params.length}`); }
  if (category) { params.push(category); where.push(`category = $${params.length}`); }
  if (language) { params.push(language); where.push(`language = $${params.length}`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await query(
    `SELECT id, title, body, category, language, is_published, review_status, reviewed_at, created_at, updated_at
     FROM legal_content ${whereSql} ORDER BY created_at DESC`,
    params,
  );
  ok(res, rows);
};

export const getLegal = async (req, res) => {
  const { rows } = await query('SELECT * FROM legal_content WHERE id = $1', [req.params.id]);
  if (!rows[0]) return fail(res, 'Not found', 404);
  const { rows: history } = await query(
    `SELECT h.*, u.full_name AS changed_by_name FROM legal_review_history h
     LEFT JOIN users u ON u.id = h.changed_by WHERE h.legal_id = $1 ORDER BY h.created_at DESC`,
    [req.params.id],
  );
  rows[0].review_history = history;
  ok(res, rows[0]);
};

export const listLegalHistory = async (req, res) => {
  const { rows } = await query(
    `SELECT h.*, u.full_name AS changed_by_name FROM legal_review_history h
     LEFT JOIN users u ON u.id = h.changed_by WHERE h.legal_id = $1 ORDER BY h.created_at DESC`,
    [req.params.id],
  );
  ok(res, rows);
};

export const createLegal = async (req, res) => {
  const { title, body, category, language, review_status } = req.body;
  if (!title || !body) return fail(res, 'title and body are required');
  const status = REVIEW_STATUSES.includes(review_status) ? review_status : 'published';
  const { rows } = await query(
    `INSERT INTO legal_content (title, body, category, language, review_status, is_published)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [title, body, category || 'general', language || 'en', status, status === 'published'],
  );
  await writeHistory(rows[0].id, 'created', null, status, 'Content created', req.user.id);
  mirrorSet('legal_content', rows[0].id, rows[0]).catch(() => {});
  ok(res, rows[0], 'Created', 201);
};

export const updateLegal = async (req, res) => {
  const { title, body, category, language, is_published, review_status, note } = req.body;
  const current = await query('SELECT * FROM legal_content WHERE id = $1', [req.params.id]);
  if (!current.rows[0]) return fail(res, 'Not found', 404);
  const prev = current.rows[0];
  const nextStatus = REVIEW_STATUSES.includes(review_status) ? review_status : prev.review_status;
  const { rows } = await query(
    `UPDATE legal_content SET title = COALESCE($1,title), body = COALESCE($2,body),
       category = COALESCE($3,category), language = COALESCE($4,language),
       is_published = COALESCE($5, is_published), review_status = $6,
       updated_at = now() WHERE id = $7 RETURNING *`,
    [title || null, body || null, category || null, language || null, is_published ?? null,
      nextStatus, req.params.id],
  );
  if (nextStatus !== prev.review_status) {
    await writeHistory(req.params.id, 'status_change', prev.review_status, nextStatus, note, req.user.id);
  } else {
    await writeHistory(req.params.id, 'updated', prev.review_status, nextStatus, note, req.user.id);
  }
  mirrorSet('legal_content', rows[0].id, rows[0]).catch(() => {});
  ok(res, rows[0], 'Updated');
};

/**
 * Mark legal content as "Under Review" (or back to published) during
 * regulatory changes (doc UC-16 alt flow 9.2 / SD-9).
 */
export const reviewLegal = async (req, res) => {
  const { review_status, note } = req.body;
  if (!REVIEW_STATUSES.includes(review_status)) {
    return fail(res, `review_status must be one of: ${REVIEW_STATUSES.join(', ')}`);
  }
  const current = await query('SELECT * FROM legal_content WHERE id = $1', [req.params.id]);
  if (!current.rows[0]) return fail(res, 'Not found', 404);
  const prev = current.rows[0];
  const isPublished = review_status === 'published';
  const { rows } = await query(
    `UPDATE legal_content SET review_status = $1, is_published = $2,
       reviewed_by = $3, reviewed_at = now(), updated_at = now()
     WHERE id = $4 RETURNING *`,
    [review_status, isPublished, req.user.id, req.params.id],
  );
  await writeHistory(req.params.id, 'review', prev.review_status, review_status, note, req.user.id);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail)
     VALUES ($1,'review_legal','legal_content',$2,$3)`,
    [req.user.id, req.params.id, JSON.stringify({ from: prev.review_status, to: review_status })],
  );
  mirrorSet('legal_content', rows[0].id, rows[0]).catch(() => {});
  ok(res, rows[0], `Legal content marked as ${review_status}`);
};

export const deleteLegal = async (req, res) => {
  await query('DELETE FROM legal_content WHERE id = $1', [req.params.id]);
  mirrorDelete('legal_content', req.params.id).catch(() => {});
  ok(res, null, 'Deleted');
};
