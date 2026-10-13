export const TOKEN_KEY = 'zega_admin_token';
export const REFRESH_KEY = 'zega_admin_refresh';
export const USER_KEY = 'zega_admin_user';

export const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '');

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
    if (res.status === 401) {
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
