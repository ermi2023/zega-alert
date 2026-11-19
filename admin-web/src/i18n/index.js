import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { API_BASE, TOKEN_KEY } from '../api/client';
import en from './en.json';
import am from './am.json';
import om from './om.json';
import ti from './ti.json';
import so from './so.json';

// The five official UI languages are all shipped as static JSON bundles, so
// they render instantly with no network call. (The remote-loading path below
// is retained for any future language added without a static bundle.)
const STATIC_RESOURCES = {
  en: { translation: en }, am: { translation: am },
  om: { translation: om }, ti: { translation: ti },
  so: { translation: so },
};
const STATIC_LANGS = new Set(Object.keys(STATIC_RESOURCES));

// Client-side cache version. Bumped when the English source bundle changes
// structurally (new keys), so stale Google-translated bundles get refreshed.
const CACHE_VERSION = '2026-11-19-v1';
const cacheKey = (lang) => `zega_i18n_${lang}@${CACHE_VERSION}`;

const savedLang = localStorage.getItem('zega_lang') || 'en';

i18n.use(initReactI18next).init({
  resources: { ...STATIC_RESOURCES },
  lng: savedLang,
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
  returnEmptyString: false,
});

// Load a non-bundled language: try localStorage cache, then the backend.
// On success, registers it as an i18n resource and switches to it. On failure,
// logs and falls back to English so the UI never blocks.
export async function loadRemoteLanguage(lang) {
  if (!lang || STATIC_LANGS.has(lang)) {
    await i18n.changeLanguage(lang);
    return;
  }

  // 1. localStorage cache (per version).
  const cached = localStorage.getItem(cacheKey(lang));
  if (cached) {
    try {
      const strings = JSON.parse(cached);
      i18n.addResourceBundle(lang, 'translation', strings, true, true);
      await i18n.changeLanguage(lang);
      return;
    } catch { /* corrupt cache — fall through to fetch */ }
  }

  // 2. Backend (Google Translate via the i18n controller).
  try {
    const token = localStorage.getItem(TOKEN_KEY);
    const res = await fetch(`${API_BASE}/api/i18n/bundle/${encodeURIComponent(lang)}`, {
      headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();
    const strings = json?.data?.strings;
    if (strings && typeof strings === 'object') {
      i18n.addResourceBundle(lang, 'translation', strings, true, true);
      try { localStorage.setItem(cacheKey(lang), JSON.stringify(strings)); } catch { /* quota */ }
      await i18n.changeLanguage(lang);
      return;
    }
  } catch (err) {
    // Provider failed — keep English so the UI renders.
    console.warn(`[i18n] Could not load language "${lang}":`, err.message);
  }
  await i18n.changeLanguage(lang); // falls back to fallbackLng ('en')
}

// Wrap changeLanguage so anywhere that calls i18n.changeLanguage directly
// (e.g. Layout.jsx's language picker) transparently handles remote languages.
const originalChangeLanguage = i18n.changeLanguage.bind(i18n);
i18n.changeLanguage = async (lang) => {
  if (lang && !STATIC_LANGS.has(lang)) {
    await loadRemoteLanguage(lang);
  } else {
    await originalChangeLanguage(lang);
  }
  localStorage.setItem('zega_lang', lang);
};

// On boot, if the saved language is remote, load it now (non-blocking — the
// app renders in English first, then swaps once the bundle arrives).
if (savedLang && !STATIC_LANGS.has(savedLang)) {
  loadRemoteLanguage(savedLang).catch(() => {});
}

export default i18n;
