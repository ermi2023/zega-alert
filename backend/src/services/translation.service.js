import { env } from '../config/env.js';

// Supported languages (doc 4.3.3): English, Amharic, Oromifa, Tigrigna.
export const LANGUAGES = ['en', 'am', 'om', 'ti'];
export const LABELS = { en: 'English', am: 'Amharic', om: 'Oromifa', ti: 'Tigrigna' };

// LibreTranslate and most self-hosted engines map Oromifa/Tigrigna differently;
// allow an alias map so the same endpoints can be reused.
const ENGINE_CODE = { en: 'en', am: 'am', om: 'om', ti: 'ti' };

/**
 * Translate a single string into `target`. When a translation API is
 * configured (TRANSLATE_API_URL) it is used; otherwise a clearly-marked
 * placeholder is returned so downstream flows never break offline.
 * @returns {Promise<{text: string, source: 'auto'|'placeholder'}>}
 */
export const translateText = async (text, target, source = 'en') => {
  if (!text) return { text, source: 'auto' };
  if (target === source) return { text, source: 'auto' };
  if (!env.translateApiUrl) {
    return { text: `[${LABELS[target] || target}] ${text}`, source: 'placeholder' };
  }
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    const resp = await fetch(env.translateApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(env.translateApiKey ? { Authorization: `Bearer ${env.translateApiKey}` } : {}),
      },
      body: JSON.stringify({
        q: text,
        source: ENGINE_CODE[source] || source,
        target: ENGINE_CODE[target] || target,
        format: 'text',
        ...(env.translateApiKey ? { api_key: env.translateApiKey } : {}),
      }),
      signal: controller.signal,
    }).finally(() => clearTimeout(timer));
    if (!resp.ok) throw new Error(`translate HTTP ${resp.status}`);
    const data = await resp.json();
    const translated = data.translatedText || data.translation || data.text;
    if (!translated) throw new Error('empty translation');
    return { text: translated, source: 'auto' };
  } catch (err) {
    console.warn('[translation] engine failed, using placeholder:', err.message);
    return { text: `[${LABELS[target] || target}] ${text}`, source: 'placeholder' };
  }
};

/**
 * Translate an announcement (title + body) into every supported language.
 * @returns {Promise<Array<{language,title,body,source}>>}
 */
export const translateAnnouncement = async ({ title, body, source = 'en' }) => {
  const out = [];
  const targets = [source, ...LANGUAGES.filter((l) => l !== source)];
  for (const lang of targets) {
    if (lang === source) {
      out.push({ language: lang, title, body, source: 'auto' });
      continue;
    }
    const [tTitle, tBody] = await Promise.all([
      translateText(title, lang, source),
      translateText(body, lang, source),
    ]);
    out.push({
      language: lang,
      title: tTitle.text,
      body: tBody.text,
      source: tTitle.source === 'placeholder' || tBody.source === 'placeholder' ? 'placeholder' : 'auto',
    });
  }
  return out;
};
