/**
 * UI localization via Google Translate (free `translate_a/single` endpoint)
 * with a keyless MyMemory fallback. Used by the admin-web frontend to render
 * the i18n bundle for any language beyond the four we ship statically
 * (am / en / om / ti). The full static English bundle is sent as the source
 * string map; this endpoint returns a translated copy, keyed by the same paths.
 *
 * Why a backend proxy instead of calling Google from the browser:
 *  - avoids CORS (the free endpoint does not send CORS headers)
 *  - lets us cache translations per language in memory + ship them as one
 *    round-trip instead of one request per string
 *  - keeps the choice of provider swappable (Google → MyMemory → future paid key)
 *
 * Auth: any logged-in user can request translations; the endpoint is read-only.
 */
import { ok, fail } from '../utils/response.js';

// Languages we ship as static JSON in admin-web/src/i18n — no need to translate.
const BUNDLED_LANGS = new Set(['en', 'am', 'om', 'ti']);

// In-memory cache: { [lang]: { version, strings } }. Survives until the process
// restarts. Versioned so a deploy that bumps BUNDLE_VERSION invalidates stale
// cache entries automatically.
const BUNDLE_VERSION = '2026-11-19-v1';
const cache = new Map();

// Source: the English bundle is the single source of truth for which keys
// exist. Loaded lazily so a backend restart after a frontend deploy picks up
// new keys without code changes.
let enBundle = null;
const loadEnBundle = async () => {
  if (enBundle) return enBundle;
  try {
    // Read the JSON the Vite build ships — admin-web is a sibling of backend.
    const url = new URL('../../admin-web/src/i18n/en.json', import.meta.url);
    const fs = await import('fs/promises');
    enBundle = JSON.parse(await fs.readFile(url, 'utf8'));
  } catch {
    // Fallback: a minimal hardcoded set so the endpoint never 500s even if the
    // admin-web source tree is not present on the server (e.g. split deploy).
    enBundle = {
      brand: 'ZEGA-ALERT',
      logout: 'Logout',
      loading: 'Loading…',
      nav: { dashboard: 'Dashboard', sos: 'SOS Alerts', reports: 'Reports',
             persons: 'Missing / Wanted', callbacks: 'Callbacks', pod: 'People of Determination',
             feedback: 'Feedback', announcements: 'Announcements', chat: 'Chat', legal: 'Legal',
             geofences: 'Safety Zones', notifications: 'Notifications' },
    };
  }
  return enBundle;
};

// Flatten a nested i18n object into { "a.b.c": "value" } pairs for translation.
const flatten = (obj, prefix = '') => {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v)) Object.assign(out, flatten(v, key));
    else out[key] = String(v);
  }
  return out;
};

// Rebuild a nested object from flattened { "a.b.c": "value" } pairs.
const unflatten = (flat) => {
  const out = {};
  for (const [k, v] of Object.entries(flat)) {
    const parts = k.split('.');
    let node = out;
    for (let i = 0; i < parts.length - 1; i++) {
      node[parts[i]] = node[parts[i]] || {};
      node = node[parts[i]];
    }
    node[parts[parts.length - 1]] = v;
  }
  return out;
};

// Batch a flat map of strings through Google's free translate endpoint.
// Returns a flat map of the same keys with translated values. Uses
// client=gtx (the public web-widget client) which is free but rate-limited;
// on any failure (429, network, blocked IP) callers should retry via MyMemory.
const translateBatchGoogle = async (flat, target) => {
  const chunks = [];
  const keys = Object.keys(flat);
  // Google accepts multiple `q=` params; keep each chunk small to stay well
  // under URL length limits (~120 strings or ~6KB per chunk).
  const CHUNK = 100;
  for (let i = 0; i < keys.length; i += CHUNK) {
    const slice = keys.slice(i, i + CHUNK);
    const url = 'https://translate.googleapis.com/translate_a/single'
      + `?client=gtx&sl=en&tl=${encodeURIComponent(target)}&dt=t`
      + slice.map(k => `&q=${encodeURIComponent(flat[k])}`).join('');
    const res = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (ZEGA-Alert)', 'Accept': 'application/json' },
    });
    if (!res.ok) throw new Error(`Google translate HTTP ${res.status}`);
    const json = await res.json();
    // Response shape: [ [ ["translated", "source", ...], ... ], ... ]
    // The first array holds sentence pairs in order; concatenate per chunk.
    const segs = json?.[0] || [];
    slice.forEach((k, idx) => {
      // Google splits long strings into multiple segments; rejoin by source
      // boundary is complex, so use the simple 1:1 mapping (works for the
      // short UI labels we ship). When the count mismatches, fall back to the
      // original string so the UI never renders `undefined`.
      const seg = segs[idx];
      flat[k] = seg?.[0] ? String(seg[0]) : flat[k];
    });
    chunks.push(slice.length);
  }
  return flat;
};

// Keyless MyMemory fallback. Translates one string at a time (no batching),
// so only used when Google is blocked / rate-limited. Capped at a handful of
// strings per request to avoid hammering the free quota.
const translateBatchMyMemory = async (flat, target) => {
  const keys = Object.keys(flat).slice(0, 40); // protect the free quota
  await Promise.all(keys.map(async (k) => {
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(flat[k])}&langpair=en|${encodeURIComponent(target)}`;
    try {
      const res = await fetch(url, { headers: { 'Accept': 'application/json' } });
      const json = await res.json();
      const t = json?.responseData?.translatedText;
      if (t && !/MYMEMORY WARNING/i.test(t)) flat[k] = String(t);
    } catch { /* leave original */ }
  }));
  return flat;
};

export const getUiBundle = async (req, res) => {
  const lang = String(req.params.lang || '').toLowerCase();
  if (!lang || !/^[a-z]{2}(-[a-z0-9]+)?$/i.test(lang)) {
    return fail(res, 'Invalid language code', 400);
  }

  // Bundled languages are served from static JSON — never translate them.
  const baseLang = lang.split('-')[0];
  if (BUNDLED_LANGS.has(baseLang)) {
    return ok(res, { lang, bundled: true, source: 'static', strings: null });
  }

  const cacheKey = `${lang}@${BUNDLE_VERSION}`;
  const hit = cache.get(cacheKey);
  if (hit) return ok(res, { lang, bundled: false, source: 'cache', strings: hit, version: BUNDLE_VERSION });

  const en = await loadEnBundle();
  const flat = flatten(en);

  // Try Google first, fall back to MyMemory, fall back to English.
  let translated;
  try {
    translated = await translateBatchGoogle({ ...flat }, lang);
  } catch (googleErr) {
    try {
      translated = await translateBatchMyMemory({ ...flat }, lang);
    } catch (mmErr) {
      // Both providers failed — return the English bundle so the UI still
      // renders; the caller treats this as "translation unavailable".
      return ok(res, { lang, bundled: false, source: 'fallback-en',
        strings: unflatten(flat), version: BUNDLE_VERSION,
        warning: 'Translation providers unavailable; showing English.' });
    }
  }

  const nested = unflatten(translated);
  cache.set(cacheKey, nested);
  ok(res, { lang, bundled: false, source: 'translate',
    strings: nested, version: BUNDLE_VERSION });
};

// List of languages offered in the Settings picker. Includes the four bundled
// ones plus every language Google supports that's relevant to the platform.
export const listLanguages = async (req, res) => {
  const languages = [
    { code: 'en', label: 'English',     bundled: true },
    { code: 'am', label: 'አማርኛ (Amharic)',     bundled: true },
    { code: 'om', label: 'Afaan Oromoo', bundled: true },
    { code: 'ti', label: 'ትግርኛ (Tigrinya)',     bundled: true },
    { code: 'fr', label: 'Français (French)' },
    { code: 'ar', label: 'العربية (Arabic)' },
    { code: 'so', label: 'Soomaali (Somali)' },
    { code: 'sw', label: 'Kiswahili (Swahili)' },
    { code: 'es', label: 'Español (Spanish)' },
    { code: 'pt', label: 'Português (Portuguese)' },
    { code: 'de', label: 'Deutsch (German)' },
    { code: 'it', label: 'Italiano (Italian)' },
    { code: 'zh-CN', label: '中文 (Chinese)' },
    { code: 'ja', label: '日本語 (Japanese)' },
    { code: 'ko', label: '한국어 (Korean)' },
    { code: 'ru', label: 'Русский (Russian)' },
    { code: 'hi', label: 'हिन्दी (Hindi)' },
    { code: 'tr', label: 'Türkçe (Turkish)' },
  ];
  ok(res, { languages });
};
