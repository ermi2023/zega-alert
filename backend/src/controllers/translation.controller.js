import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

const LANGUAGES = ['en', 'am', 'om', 'ti'];
const LABELS = { en: 'English', am: 'Amharic', om: 'Oromifa', ti: 'Tigrigna' };

export const listTranslations = async (req, res) => {
  const { rows } = await query(
    'SELECT * FROM announcement_translations WHERE announcement_id = $1 ORDER BY language',
    [req.params.announcementId],
  );
  ok(res, rows);
};

export const upsertTranslation = async (req, res) => {
  const { announcement_id, language, title, body, source } = req.body;
  if (!announcement_id || !language || !title || !body) {
    return fail(res, 'announcement_id, language, title, and body are required');
  }
  if (!LANGUAGES.includes(language)) {
    return fail(res, `language must be one of: ${LANGUAGES.join(', ')}`);
  }
  const { rows } = await query(
    `INSERT INTO announcement_translations (announcement_id, language, title, body, source)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (announcement_id, language)
     DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, source = EXCLUDED.source
     RETURNING *`,
    [announcement_id, language, title, body, source || 'manual'],
  );
  ok(res, rows[0], 'Translation saved', 201);
};

export const deleteTranslation = async (req, res) => {
  await query('DELETE FROM announcement_translations WHERE id = $1', [req.params.id]);
  ok(res, null, 'Deleted');
};

export const bulkCreatePlaceholders = async (req, res) => {
  const { announcement_id, title_en, body_en } = req.body;
  if (!announcement_id || !title_en || !body_en) {
    return fail(res, 'announcement_id, title_en, and body_en are required');
  }
  const inserted = [];
  for (const lang of LANGUAGES) {
    if (lang === 'en') continue;
    const { rows } = await query(
      `INSERT INTO announcement_translations (announcement_id, language, title, body, source)
       VALUES ($1, $2, $3, $4, 'placeholder')
       ON CONFLICT (announcement_id, language) DO NOTHING
       RETURNING *`,
      [announcement_id, lang, `[${LABELS[lang]}] ${title_en}`, `[${LABELS[lang]}] ${body_en}`],
    );
    if (rows[0]) inserted.push(rows[0]);
  }
  ok(res, { count: inserted.length, translations: inserted }, 'Placeholders created', 201);
};
