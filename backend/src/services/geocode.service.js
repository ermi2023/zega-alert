import { env } from '../config/env.js';

const CLIENT_URL = 'https://api.bigdatacloud.net/data/reverse-geocode-client';
const DEFAULT_TIMEOUT_MS = 4000;
const CACHE_LIMIT = 1000;

// Optional. The client endpoint is keyless; a key only raises rate limits.
const API_KEY = env.bigDataCloudApiKey;

// Values the mobile client sends when it has no real address yet.
const PLACEHOLDERS = new Set([
  'emergency from mobile app', 'unknown', 'unknown location', 'no address',
  'n/a', 'na', 'none', '-', '—', '.',
]);

const cache = new Map();

export const isPlaceholderAddress = (value) => {
  if (value == null) return true;
  const v = String(value).trim().toLowerCase();
  return v === '' || PLACEHOLDERS.has(v);
};

const dedupe = (parts) => {
  const out = [];
  for (const part of parts) {
    const s = String(part ?? '').trim();
    if (!s) continue;
    if (out.some((o) => o.toLowerCase() === s.toLowerCase())) continue;
    out.push(s);
  }
  return out;
};

export const formatAddress = (data = {}) =>
  dedupe([data.locality, data.city, data.principalSubdivision, data.countryName]).join(', ');

const cachePut = (key, value) => {
  if (cache.size >= CACHE_LIMIT) cache.delete(cache.keys().next().value);
  cache.set(key, value);
};

/**
 * Reverse geocode coordinates using BigDataCloud's keyless client endpoint.
 * Never throws - resolves to null on any failure so callers can continue
 * storing a report/SOS without an address.
 */
export async function reverseGeocode(latitude, longitude, { locale = 'en', timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

  const key = `${lat.toFixed(3)},${lng.toFixed(3)}|${locale}`;
  if (cache.has(key)) return cache.get(key);

  const url = `${CLIENT_URL}?latitude=${lat}&longitude=${lng}&localityLanguage=${encodeURIComponent(locale)}${API_KEY ? `&key=${encodeURIComponent(API_KEY)}` : ''}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) return null;
    const data = await res.json();
    const address = formatAddress(data);
    if (!address) return null;
    const result = {
      address,
      locality: data.locality || null,
      city: data.city || null,
      region: data.principalSubdivision || null,
      country: data.countryName || null,
      plusCode: data.plusCode || null,
    };
    cachePut(key, result);
    return result;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Keep a caller supplied address when it already names a place, otherwise
 * derive one from the coordinates.
 */
export async function resolveAddress({ latitude, longitude, address_text, locale, timeoutMs } = {}) {
  if (!isPlaceholderAddress(address_text)) return address_text;
  if (latitude == null || longitude == null) return address_text || null;
  const geo = await reverseGeocode(latitude, longitude, { locale, timeoutMs });
  return geo?.address || address_text || null;
}
