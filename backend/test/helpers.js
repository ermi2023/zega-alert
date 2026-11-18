import app from '../src/app.js';
import { pool } from '../src/config/db.js';

/**
 * Boot the Express app on an ephemeral port so the suite never clashes with a
 * running dev server on :5000.
 */
export async function startServer() {
  const server = app.listen(0, '127.0.0.1');
  if (!server.listening) {
    await new Promise((resolve) => server.once('listening', resolve));
  }
  const { port } = server.address();
  return {
    baseUrl: `http://127.0.0.1:${port}`,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

export async function endPool() {
  await pool.end();
}

/** Minimal fetch wrapper returning { status, body, headers }. */
export async function api(baseUrl, path, options = {}) {
  const { method = 'GET', token, body, rawBody, headers = {} } = options;
  const init = { method, headers: { ...headers } };
  if (body !== undefined) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(body);
  } else if (rawBody !== undefined) {
    init.headers['Content-Type'] = 'application/json';
    init.body = rawBody;
  }
  if (token) init.headers.Authorization = `Bearer ${token}`;

  const res = await fetch(baseUrl + path, init);
  const text = await res.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }
  return { status: res.status, body: parsed, text };
}

/** Login helper for the seeded demo accounts (password: password123). */
export async function login(baseUrl, phone, password = 'password123') {
  const res = await api(baseUrl, '/api/auth/login', { method: 'POST', body: { phone, password } });
  return { ...res, token: res.body?.data?.accessToken };
}

export const DEMO = {
  admin: '0911000006',
  regionalAdmin: '0911000002',
  dispatcher: '0911000003',
  police: '0911000004',
  citizen: '0911000005',
  citizen2: '0911999999',
};
