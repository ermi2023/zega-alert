import { translateText, translateBatch, LANGUAGES, LABELS, SHORT_CODES } from '../services/translation.service.js';
import { ok, fail } from '../utils/response.js';

/**
 * POST /api/translate
 *
 * On-demand translation of arbitrary text. Used by the mobile app for
 * news cards and missing/wanted person descriptions.
 *
 * Body:
 *   { text: string, target: 'en'|'am'|'om'|'ti'|'so', source?: string }
 *   OR
 *   { texts: string[], target, source? }
 *
 * Response:
 *   { success, data: { text, source, cached, target } | { items: [...] } }
 *
 * When no provider is configured, returns a `[Lang] original` placeholder
 * so the UI can still show *something* and the flow never breaks offline.
 */
export const translate = async (req, res) => {
  const { text, texts, target, source } = req.body || {};

  if (!target) return fail(res, 'target is required');
  if (!LANGUAGES.includes(target)) {
    return fail(res, `target must be one of: ${LANGUAGES.join(', ')}`);
  }
  if (source && !LANGUAGES.includes(source)) {
    return fail(res, `source must be one of: ${LANGUAGES.join(', ')} or omitted`);
  }

  // Batch mode
  if (Array.isArray(texts)) {
    if (texts.length === 0) return ok(res, { items: [] });
    if (texts.length > 25) return fail(res, 'too many strings (max 25 per call)');
    const results = await translateBatch(texts, target, source || 'en');
    return ok(res, { items: results });
  }

  // Single mode
  if (typeof text !== 'string') {
    return fail(res, 'either text (string) or texts (array) is required');
  }
  if (text.length > 5000) {
    return fail(res, 'text too long (max 5000 chars)');
  }

  const result = await translateText(text, target, source || 'en');
  return ok(res, result);
};

/**
 * GET /api/translate/languages
 * Returns the list of supported languages with their labels and short codes.
 */
export const listLanguages = (req, res) => {
  const langs = LANGUAGES.map((code) => ({
    code,
    label: LABELS[code] || code,
    short: SHORT_CODES[code] || code,
  }));
  return ok(res, { languages: langs });
};
