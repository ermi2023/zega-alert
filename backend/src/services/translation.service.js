import { env } from '../config/env.js';

// Supported languages (doc 4.3.3): English, Amharic, Oromifa, Tigrigna, Somali.
export const LANGUAGES = ['en', 'am', 'om', 'ti', 'so'];
export const LABELS = {
  en: 'English',
  am: 'Amharic',
  om: 'Oromifa',
  ti: 'Tigrigna',
  so: 'Somali',
};

// Display short codes used by the mobile app language picker.
export const SHORT_CODES = {
  en: 'en',
  am: 'amh',
  om: 'orm',
  ti: 'tigir',
  so: 'som',
};

// LibreTranslate and most self-hosted engines map Oromifa/Tigrigna differently;
// allow an alias map so the same endpoints can be reused.
const ENGINE_CODE = { en: 'en', am: 'am', om: 'om', ti: 'ti', so: 'so' };

// ---------------------------------------------------------------------------
// In-memory LRU cache. Keyed by `${target}::${sha-ish(text)}`. Capped at 500
// entries so the process stays bounded; oldest entries are evicted first.
// ---------------------------------------------------------------------------
const CACHE_MAX = 500;
const _cache = new Map(); // Map preserves insertion order in JS
function cacheGet(key) {
  if (!_cache.has(key)) return undefined;
  const value = _cache.get(key);
  // Refresh recency: delete + re-insert moves it to the end.
  _cache.delete(key);
  _cache.set(key, value);
  return value;
}
function cacheSet(key, value) {
  if (_cache.has(key)) _cache.delete(key);
  _cache.set(key, value);
  while (_cache.size > CACHE_MAX) {
    const oldest = _cache.keys().next().value;
    _cache.delete(oldest);
  }
}
function cacheKey(target, text) {
  // Use a simple length+hash to keep the key short. Collisions are rare for
  // natural-language strings of similar length and the worst case is a cache
  // miss (re-fetch from the engine).
  let h = 0;
  for (let i = 0; i < text.length; i++) {
    h = ((h << 5) - h + text.charCodeAt(i)) | 0;
  }
  return `${target}::${text.length}::${h}`;
}

/**
 * Detect which translation backend to use based on env configuration.
 *  - TRANSLATE_PROVIDER=google  -> Google Cloud Translation API v2 (key-based)
 *  - TRANSLATE_PROVIDER=libre    -> LibreTranslate-style POST (default if URL set)
 *  - otherwise                    -> placeholder mode
 */
function detectProvider() {
  const provider = (process.env.TRANSLATE_PROVIDER || '').toLowerCase();
  if (provider === 'google' || (env.googleTranslateApiKey && !env.translateApiUrl)) {
    return 'google';
  }
  if (env.translateApiUrl) return 'libre';
  return 'placeholder';
}

/**
 * Call Google Cloud Translation API v2 (Basic).
 * Endpoint: https://translation.googleapis.com/language/translate/v2?key=API_KEY
 * Body: { q, source, target, format }
 */
async function callGoogle(text, source, target) {
  const key = env.googleTranslateApiKey || env.translateApiKey;
  if (!key) throw new Error('google_translate_no_api_key');
  const url = 'https://translation.googleapis.com/language/translate/v2';
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const resp = await fetch(`${url}?key=${encodeURIComponent(key)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        q: text,
        source: ENGINE_CODE[source] || source,
        target: ENGINE_CODE[target] || target,
        format: 'text',
      }),
      signal: controller.signal,
    });
    if (!resp.ok) {
      const detail = await resp.text().catch(() => '');
      throw new Error(`google_translate_http_${resp.status}: ${detail.slice(0, 200)}`);
    }
    const data = await resp.json();
    // Google v2 returns { data: { translations: [{ translatedText, detectedSourceLanguage }] } }
    const translated = data?.data?.translations?.[0]?.translatedText;
    if (!translated) throw new Error('google_translate_empty_response');
    return decodeEntities(translated);
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Call a LibreTranslate-compatible endpoint.
 */
async function callLibre(text, source, target) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
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
    });
    if (!resp.ok) throw new Error(`libre_http_${resp.status}`);
    const data = await resp.json();
    const translated = data.translatedText || data.translation || data.text;
    if (!translated) throw new Error('libre_empty_response');
    return translated;
  } finally {
    clearTimeout(timer);
  }

  /**
   * No-key fallback for deployments that have not configured Google credentials.
   * Uses Google's public translation web endpoint. It is rate-limited and is only
   * a fallback; Google Cloud credentials are preferred by callGoogle().
   */
  async function callGooglePublic(text, source, target) {
    const params = new URLSearchParams({
      client: 'gtx',
      sl: ENGINE_CODE[source] || source,
      tl: ENGINE_CODE[target] || target,
      dt: 't',
      q: text,
    });
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    try {
      const resp = await fetch(`https://translate.googleapis.com/translate_a/single?${params}`, {
        headers: { 'User-Agent': 'ZEGA-ALERT/1.0' },
        signal: controller.signal,
      });
      if (!resp.ok) throw new Error(`google_public_http_${resp.status}`);
      const data = await resp.json();
      if (!Array.isArray(data) || !Array.isArray(data[0])) {
        throw new Error('google_public_empty_response');
      }
      const translated = data[0]
        .map((part) => (Array.isArray(part) ? part[0] : ''))
        .join('');
      if (!translated.trim()) throw new Error('google_public_empty_response');
      return decodeEntities(translated);
    } finally {
      clearTimeout(timer);
    }
  }
}

// Google escapes some HTML entities in translatedText; decode the common ones.
function decodeEntities(s) {
  return s
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

/**
 * Translate a single string into `target`. When a translation API is
 * configured (TRANSLATE_API_URL or Google Cloud credentials) it is used;
 * otherwise a clearly-marked placeholder is returned so downstream flows
 * never break offline.
 *
 * @param {string} text     Source text to translate.
 * @param {string} target   Target language code (en/am/om/ti/so).
 * @param {string} [source] Source language code (default 'en').
 * @param {object} [opts]   { useCache: true (default) }
 * @returns {Promise<{text: string, source: 'auto'|'placeholder', cached?: boolean, target: string}>}
 */
export const translateText = async (text, target, source = 'en', opts = {}) => {
  const useCache = opts.useCache !== false;
  if (!text) return { text, source: 'auto', target };
  if (target === source) return { text, source: 'auto', target };

  const key = cacheKey(target, text);
  if (useCache) {
    const cached = cacheGet(key);
    if (cached) return { text: cached, source: 'auto', cached: true, target };
  }

  const provider = detectProvider();
  if (provider === 'placeholder') {
    try {
      const translated = await callGooglePublic(text, source, target);
      if (useCache) cacheSet(key, translated);
      return { text: translated, source: 'google-public', target };
    } catch (err) {
      console.warn(`[translation] public Google fallback failed: ${err.message}`);
      const placeholder = text;
      return { text: placeholder, source: 'original', target };
    }
  }

  try {
    const translated =
      provider === 'google'
        ? await callGoogle(text, source, target)
        : await callLibre(text, source, target);
    if (useCache) cacheSet(key, translated);
    return { text: translated, source: 'auto', target };
  } catch (err) {
    console.warn(`[translation] ${provider} engine failed, using placeholder:`, err.message);
    const placeholder = `[${LABELS[target] || target}] ${text}`;
    return { text: placeholder, source: 'placeholder', target };
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

/**
 * Translate multiple strings in one call (used by the on-demand
 * /api/translate endpoint when the caller passes an array). Reuses the cache
 * per-string and runs independent strings concurrently.
 * @returns {Promise<Array<{text, source, target, cached?}>>}
 */
export const translateBatch = async (texts, target, source = 'en') => {
  if (!Array.isArray(texts) || texts.length === 0) return [];
  return Promise.all(texts.map((t) => translateText(t, target, source)));
};
