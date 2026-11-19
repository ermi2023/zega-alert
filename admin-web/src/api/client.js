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
  if (/^(https?:|data:|blob:)/.test(url)) return url;
  const base = API_BASE || (window.location.hostname === 'localhost' ? 'http://localhost:5000' : '');
  return `${base}${url.startsWith('/') ? '' : '/'}${url}`;
};

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
