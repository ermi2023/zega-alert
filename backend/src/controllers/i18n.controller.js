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

// Languages we ship as static JSON bundles — no need to translate. Includes
// Somali because the so.json file is generated once and shipped statically.
const BUNDLED_LANGS = new Set(['en', 'am', 'om', 'ti', 'so']);

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
    // Three levels up from backend/src/controllers/ reaches the repo root.
    const url = new URL('../../../admin-web/src/i18n/en.json', import.meta.url);
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
// We send ONE q= per HTTP request (not multiple q= in one request) because
// Google's multi-q response packs sentences into segments in a way that
// doesn't map 1:1 to the input q params — short labels get dropped or
// misaligned. One-at-a-time is slower but unambiguous. Concurrency is capped
// so we don't trip Google's rate limiter.
const translateOneGoogle = async (text, target) => {
  const url = 'https://translate.googleapis.com/translate_a/single'
    + `?client=gtx&sl=en&tl=${encodeURIComponent(target)}&dt=t`
    + `&q=${encodeURIComponent(text)}`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (ZEGA-Alert)', 'Accept': 'application/json' },
  });
  if (!res.ok) throw new Error(`Google translate HTTP ${res.status}`);
  const json = await res.json();
  // Response: [ [ ["translated", "source", ...], ... ], ... ]. The first
  // array holds sentence segments; concatenate all [0] entries to get the
  // full translation (Google splits long source strings into multiple segments).
  const segs = json?.[0] || [];
  return segs.map((s) => s?.[0]).filter(Boolean).join('') || text;
};

const translateBatchGoogle = async (flat, target) => {
  const keys = Object.keys(flat);
  const CONCURRENCY = 8; // parallel requests — high enough to be fast, low enough to avoid rate limits
  let cursor = 0;
  const workers = Array.from({ length: CONCURRENCY }, async () => {
    while (cursor < keys.length) {
      const k = keys[cursor++];
      try {
        flat[k] = await translateOneGoogle(flat[k], target);
      } catch { /* leave original — caller falls back to MyMemory */ }
    }
  });
  await Promise.all(workers);
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

// Translate an arbitrary flat map of strings (e.g. a Flutter .arb key->value
// dump) into the target language. Used as a one-shot generation tool to
// produce static translation bundles (e.g. app_so.arb) — NOT called at runtime
// by the UI. Auth required so it can't be abused as an open translate proxy.
// Body: { target: 'so', strings: { k0: 'v0', k1: 'v1', ... } }
// Returns: { target, source, strings: { k0: '...', k1: '...' } }
export const translateStrings = async (req, res) => {
  const target = String(req.body?.target || '').toLowerCase();
  const strings = req.body?.strings;
  if (!target || !/^[a-z]{2}(-[a-z0-9]+)?$/i.test(target)) {
    return fail(res, 'Invalid target language code', 400);
  }
  if (!strings || typeof strings !== 'object' || Array.isArray(strings)) {
    return fail(res, 'strings must be a flat object of { key: value }', 400);
  }
  // Reject huge payloads — this is a dev-time tool, not a public API.
  const keys = Object.keys(strings);
  if (keys.length > 500) {
    return fail(res, 'Too many strings (max 500). Split into batches.', 400);
  }
  // Normalize values to strings; preserve non-string as-is in the response.
  const flat = {};
  for (const k of keys) flat[k] = String(strings[k]);

  let translated;
  try {
    translated = await translateBatchGoogle({ ...flat }, target);
  } catch (googleErr) {
    try {
      translated = await translateBatchMyMemory({ ...flat }, target);
    } catch (mmErr) {
      return fail(res, 'Translation providers unavailable. Try again later.', 502);
    }
  }
  ok(res, { target, source: 'translate', strings: translated });
};

// List of languages offered in the Settings picker. The four original UI
// languages are bundled as static JSON; Somali is also bundled (the so.json
// file is generated once via translateStrings and shipped statically), so all
// five render instantly with no network call.
export const listLanguages = async (req, res) => {
  const languages = [
    { code: 'en', label: 'English',                 bundled: true },
    { code: 'am', label: 'አማርኛ (Amharic)',          bundled: true },
    { code: 'om', label: 'Afaan Oromoo (Oromifa)',  bundled: true },
    { code: 'ti', label: 'ትግርኛ (Tigrinya)',         bundled: true },
    { code: 'so', label: 'Soomaali (Ethio Somali)', bundled: true },
  ];
  ok(res, { languages });
};
