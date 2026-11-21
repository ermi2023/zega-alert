export const TOKEN_KEY = 'zega_admin_token';
export const REFRESH_KEY = 'zega_admin_refresh';
export const USER_KEY = 'zega_admin_user';

// Public URL of the deployed backend. Used as a fallback for production builds
// when VITE_API_URL was not provided, so the static site does not silently call
// its own domain (which is rewritten to index.html and returns HTML, not JSON).
const PROD_API_BASE = 'https://zega-alert-api.onrender.com';
export const API_BASE = (
  import.meta.env.VITE_API_URL ||
  (import.meta.env.PROD ? PROD_API_BASE : (window.location.hostname === 'localhost' ? 'http://localhost:5000' : ''))
).replace(/\/$/, '');

// Resolve a stored upload path into an absolute URL. Backends may return either
// relative paths (`/uploads/...`) or absolute Firebase URLs.
export const assetUrl = (url) => {
  if (!url) return url;
  if (/^https?:\/\//i.test(url)) {
    try {
      const parsed = new URL(url);
      if (parsed.hostname === 'www.google.com' || parsed.hostname === 'google.com') {
        const directImage = parsed.searchParams.get('imgurl');
        if (directImage) return directImage;
      }
      if (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1') {
        const prodBase = import.meta.env.PROD ? PROD_API_BASE : API_BASE;
        return `${prodBase}${parsed.pathname}${parsed.search}`;
      }
      return url;
    } catch {
      return url;
    }
  }
  if (/^(data:|blob:)/.test(url)) return url;
  const base = API_BASE || (window.location.hostname === 'localhost' ? 'http://localhost:5000' : '');
  return `${base}${url.startsWith('/') ? '' : '/'}${url}`;
};

export const IMAGE_PLACEHOLDER =
  'data:image/svg+xml;charset=UTF-8,' +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240">
      <rect width="240" height="240" fill="#1f2937"/>
      <circle cx="120" cy="82" r="42" fill="#64748b"/>
      <path d="M48 210c8-52 38-78 72-78s64 26 72 78" fill="#64748b"/>
    </svg>`
  );

const request = async (path, options = {}) => {
  const token = localStorage.getItem(TOKEN_KEY);
  const res = await fetch(`${API_BASE}/api${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
  });
  let data;
  try { data = await res.json(); } catch { data = {}; }
  if (!res.ok) {
    if (res.status === 401 && token) {
      // Only treat it as an expired session when a token was actually sent;
      // a failed login attempt should surface the error, not reload the page.
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(REFRESH_KEY);
      localStorage.removeItem(USER_KEY);
      window.location.href = '/login';
    }
    const err = new Error(data.message || 'Request failed');
    err.status = res.status;
    throw err;
  }
  return data.data;
};

export const api = {
  get: (path) => request(path),
  post: (path, body) => request(path, { method: 'POST', body: JSON.stringify(body) }),
  patch: (path, body) => request(path, { method: 'PATCH', body: JSON.stringify(body) }),
  put: (path, body) => request(path, { method: 'PUT', body: JSON.stringify(body) }),
  del: (path, body) => request(path, { method: 'DELETE', ...(body ? { body: JSON.stringify(body) } : {}) }),
};
