import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { mirrorSet, mirrorDelete } from '../services/firebase.service.js';
import { writeAudit } from '../utils/audit.js';
import { translateAnnouncement } from '../services/translation.service.js';

const REVIEW_STATUSES = ['published', 'under_review', 'draft'];

const buildTranslations = async (title, body, language) => {
  const rows = await translateAnnouncement({ title, body, source: language || 'en' });
  return Object.fromEntries(rows.map((r) => [r.language, { title: r.title, body: r.body }]));
};

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
    `SELECT id, title, body, category, language, translations, is_published, review_status,
            reviewed_at, created_at, updated_at
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
  const translations = await buildTranslations(title, body, language || 'en');
  const { rows } = await query(
    `INSERT INTO legal_content (title, body, category, language, translations, review_status, is_published)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [title, body, category || 'general', language || 'en', JSON.stringify(translations), status, status === 'published'],
  );
  await writeHistory(rows[0].id, 'created', null, status, 'Content created', req.user.id);
  // Audit: legal content creation (spec §9.2 + business rule §14.3 / §14.11).
  await writeAudit({
    userId: req.user.id,
    action: 'create_legal',
    entity: 'legal_content',
    entityId: rows[0].id,
    detail: { title: rows[0].title, category: rows[0].category, language: rows[0].language, review_status: status },
    req,
  });
  mirrorSet('legal_content', rows[0].id, rows[0]).catch(() => {});
  ok(res, rows[0], 'Created', 201);
};

export const updateLegal = async (req, res) => {
  const { title, body, category, language, is_published, review_status, note } = req.body;
  const current = await query('SELECT * FROM legal_content WHERE id = $1', [req.params.id]);
  if (!current.rows[0]) return fail(res, 'Not found', 404);
  const prev = current.rows[0];
  const nextStatus = REVIEW_STATUSES.includes(review_status) ? review_status : prev.review_status;
  const nextTitle = title || prev.title;
  const nextBody = body || prev.body;
  const nextLanguage = language || prev.language || 'en';
  const contentChanged = nextTitle !== prev.title || nextBody !== prev.body || nextLanguage !== prev.language;
  const translations = contentChanged
    ? await buildTranslations(nextTitle, nextBody, nextLanguage)
    : prev.translations;
  const { rows } = await query(
    `UPDATE legal_content SET title = COALESCE($1,title), body = COALESCE($2,body),
       category = COALESCE($3,category), language = COALESCE($4,language),
       translations = $5, is_published = COALESCE($6, is_published), review_status = $7,
       updated_at = now() WHERE id = $8 RETURNING *`,
    [title || null, body || null, category || null, language || null,
      JSON.stringify(translations || {}), is_published ?? null, nextStatus, req.params.id],
  );
  if (nextStatus !== prev.review_status) {
    await writeHistory(req.params.id, 'status_change', prev.review_status, nextStatus, note, req.user.id);
  } else {
    await writeHistory(req.params.id, 'updated', prev.review_status, nextStatus, note, req.user.id);
  }
  // Audit: legal content update (spec §9.3 + business rule §14.3 / §14.11).
  // Capture the diff so reviewers can see exactly what changed.
  const diff = {};
  for (const k of ['title', 'body', 'category', 'language', 'is_published', 'review_status']) {
    if (req.body[k] !== undefined && JSON.stringify(prev[k]) !== JSON.stringify(rows[0][k])) {
      diff[k] = { from: prev[k], to: rows[0][k] };
    }
  }
  await writeAudit({
    userId: req.user.id,
    action: 'update_legal',
    entity: 'legal_content',
    entityId: rows[0].id,
    detail: { title: rows[0].title, diff, note: note || null },
    req,
  });
  // If publish state flipped via this endpoint, record a publish/unpublish row too.
  if (prev.is_published !== rows[0].is_published) {
    await writeAudit({
      userId: req.user.id,
      action: rows[0].is_published ? 'publish_legal' : 'unpublish_legal',
      entity: 'legal_content',
      entityId: rows[0].id,
      detail: { title: rows[0].title, from: prev.is_published, to: rows[0].is_published },
      req,
    });
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
  await writeAudit({
    userId: req.user.id,
    action: 'review_legal',
    entity: 'legal_content',
    entityId: rows[0].id,
    detail: { title: rows[0].title, from: prev.review_status, to: review_status, note: note || null },
    req,
  });
  // If this review resulted in a publish, record a publish action too (spec §9.5).
  if (review_status === 'published' && prev.review_status !== 'published') {
    await writeAudit({
      userId: req.user.id,
      action: 'publish_legal',
      entity: 'legal_content',
      entityId: rows[0].id,
      detail: { title: rows[0].title, from: prev.review_status, to: review_status },
      req,
    });
  }
  mirrorSet('legal_content', rows[0].id, rows[0]).catch(() => {});
  ok(res, rows[0], `Legal content marked as ${review_status}`);
};

export const translateLegal = async (req, res) => {
  const current = await query('SELECT * FROM legal_content WHERE id = $1', [req.params.id]);
  if (!current.rows[0]) return fail(res, 'Not found', 404);
  const item = current.rows[0];
  const translations = await buildTranslations(item.title, item.body, item.language || 'en');
  const { rows } = await query(
    'UPDATE legal_content SET translations = $1, updated_at = now() WHERE id = $2 RETURNING *',
    [JSON.stringify(translations), item.id],
  );
  await writeHistory(item.id, 'translated', item.review_status, item.review_status, 'Translations regenerated', req.user.id);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail)
     VALUES ($1,'translate_legal','legal_content',$2,$3)`,
    [req.user.id, item.id, JSON.stringify({ languages: Object.keys(translations) })],
  );
  ok(res, rows[0], 'Translations updated');
};

export const deleteLegal = async (req, res) => {
  const current = await query('SELECT id, title, category, review_status FROM legal_content WHERE id = $1', [req.params.id]);
  if (!current.rows[0]) return fail(res, 'Not found', 404);
  const t = current.rows[0];
  await query('DELETE FROM legal_content WHERE id = $1', [req.params.id]);
  // Audit: legal content deletion (spec §9 + business rule §14.3 / §14.11).
  await writeAudit({
    userId: req.user.id,
    action: 'delete_legal',
    entity: 'legal_content',
    entityId: t.id,
    detail: { title: t.title, category: t.category, review_status: t.review_status, deleted_by: req.user.role },
    req,
  });
  mirrorDelete('legal_content', req.params.id).catch(() => {});
  ok(res, null, 'Deleted');
};
