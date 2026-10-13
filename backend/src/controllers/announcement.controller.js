import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { mirrorSet, mirrorDelete } from '../services/firebase.service.js';
import { translateAnnouncement } from '../services/translation.service.js';

const CATEGORIES = ['news', 'warning', 'legal', 'event', 'road_closure', 'missing_item', 'wanted', 'missing'];

export const createAnnouncement = async (req, res) => {
  const { title, body, category, region, sub_city, language } = req.body;
  if (!title || !body) return fail(res, 'title and body are required');
  if (category && !CATEGORIES.includes(category)) {
    return fail(res, `category must be one of: ${CATEGORIES.join(', ')}`);
  }
  const lang = language || 'en';
  const { rows } = await query(
    `INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [title, body, category || 'news', lang, region || null, sub_city || null, req.user.id],
  );
  const announcement = rows[0];

  // Automatic translation engine (doc 4.3.3) — translates into all four
  // supported languages before publishing; falls back to placeholders offline.
  const translations = await translateAnnouncement({ title, body, source: lang });
  for (const t of translations) {
    await query(
      `INSERT INTO announcement_translations (announcement_id, language, title, body, source)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (announcement_id, language)
       DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, source = EXCLUDED.source`,
      [announcement.id, t.language, t.title, t.body, t.source],
    );
  }

  mirrorSet('announcements', announcement.id, announcement).catch(() => {});
  ok(res, { ...announcement, translations }, 'Announcement published', 201);
};

/**
 * Re-run the translation engine for an existing announcement, e.g. after an
 * edit or when the engine becomes available.
 */
export const retranslateAnnouncement = async (req, res) => {
  const { rows } = await query('SELECT * FROM announcements WHERE id = $1', [req.params.id]);
  if (!rows[0]) return fail(res, 'Not found', 404);
  const a = rows[0];
  const translations = await translateAnnouncement({ title: a.title, body: a.body, source: a.language || 'en' });
  for (const t of translations) {
    await query(
      `INSERT INTO announcement_translations (announcement_id, language, title, body, source)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (announcement_id, language)
       DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, source = EXCLUDED.source`,
      [a.id, t.language, t.title, t.body, t.source],
    );
  }
  ok(res, translations, 'Translations regenerated');
};

export const listAnnouncements = async (req, res) => {
  const { region, sub_city, category, language } = req.query;
  const where = [];
  const params = [];
  if (region) { params.push(region); where.push(`(a.region = $${params.length} OR a.region IS NULL)`); }
  if (sub_city) { params.push(sub_city); where.push(`(a.sub_city = $${params.length} OR a.sub_city IS NULL)`); }
  if (category) { params.push(category); where.push(`a.category = $${params.length}`); }
  if (language) { params.push(language); where.push(`a.language = $${params.length}`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await query(
    `SELECT a.*, u.full_name AS author_name FROM announcements a
     LEFT JOIN users u ON u.id = a.author_id ${whereSql} ORDER BY a.published_at DESC`,
    params,
  );

  // Attach translations for each announcement
  for (const row of rows) {
    const { rows: trans } = await query(
      'SELECT * FROM announcement_translations WHERE announcement_id = $1 ORDER BY language',
      [row.id],
    );
    row.translations = trans;
  }

  ok(res, rows);
};

export const getAnnouncement = async (req, res) => {
  const { rows } = await query('SELECT * FROM announcements WHERE id = $1', [req.params.id]);
  if (!rows[0]) return fail(res, 'Not found', 404);
  const { rows: trans } = await query(
    'SELECT * FROM announcement_translations WHERE announcement_id = $1 ORDER BY language',
    [req.params.id],
  );
  rows[0].translations = trans;
  ok(res, rows[0]);
};

export const updateAnnouncement = async (req, res) => {
  const { title, body, category, is_published } = req.body;
  const { rows } = await query(
    `UPDATE announcements SET title = COALESCE($1, title), body = COALESCE($2, body),
       category = COALESCE($3, category), is_published = COALESCE($4, is_published)
     WHERE id = $5 RETURNING *`,
    [title || null, body || null, category || null, is_published ?? null, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  mirrorSet('announcements', rows[0].id, rows[0]).catch(() => {});
  ok(res, rows[0], 'Updated');
};

export const deleteAnnouncement = async (req, res) => {
  await query('DELETE FROM announcements WHERE id = $1', [req.params.id]);
  mirrorDelete('announcements', req.params.id).catch(() => {});
  ok(res, null, 'Deleted');
};
