// GeoAPI.info client (https://geoapi.info). This is a *complement* to
// geocode.service.js (BigDataCloud reverse geocoding):
//
//   * BigDataCloud - coordinates -> street/locality address (backend side).
//   * GeoAPI       - reference data (country facts) and, on-device only, a
//                    coarse network/IP location fallback.
//
// GeoAPI's /api/geo resolves the *calling* IP, so it is useless server-side
// (a Render call would geolocate Render). The mobile app calls it directly;
// the backend only uses GeoAPI's IP-independent reference endpoints here.
//
// Holiday names from GeoAPI are corrupted (Amharic stored as '?'), so holidays
// are intentionally NOT surfaced.

const BASE_URL = 'https://geoapi.info/api';
const DEFAULT_TIMEOUT_MS = 5000;
const CACHE_LIMIT = 500;

const cache = new Map();

// Required attribution for the ISO 3166 country data (CC BY-SA 4.0).
const ATTRIBUTION = {
  source: 'GeoAPI.info',
  license: 'CC BY-SA 4.0',
  url: 'https://geoapi.info',
};

const cachePut = (key, value) => {
  if (cache.size >= CACHE_LIMIT) cache.delete(cache.keys().next().value);
  cache.set(key, value);
};

const getJson = async (path, timeoutMs) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(`${BASE_URL}${path}`, { signal: controller.signal });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
};

/**
 * Country reference facts (capital, calling code, currency, languages, region
 * count). Never throws - resolves to null on any failure so callers can skip
 * rendering the reference gracefully.
 */
export async function getCountryInfo(code = 'ET', { timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  const c = String(code || 'ET').trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(c)) return null;

  const key = `country:${c}`;
  if (cache.has(key)) return cache.get(key);

  const data = await getJson(`/country?code=${c}`, timeoutMs);
  if (!data) return null;

  const info = {
    code: data.code || c,
    name: data.name || null,
    capital: data.capitalCity || null,
    continent: data.continent || null,
    callingCode: data.callingCode ?? null,
    currencyCode: data.currencyCode || null,
    currencyName: data.currencyName || null,
    languages: Array.isArray(data.languages) ? data.languages : [],
    subdivisionCount: data.subdivisionCount ?? null,
    coordinates: data.coordinates || null,
    attribution: ATTRIBUTION,
  };
  cachePut(key, info);
  return info;
}
