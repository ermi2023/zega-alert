import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { startServer, endPool, api, login, DEMO } from './helpers.js';

let ctx;

before(async () => {
  ctx = await startServer();
});

after(async () => {
  await ctx.close();
  await endPool();
});

test('seeded admin can log in and receives access + refresh tokens', async () => {
  const res = await login(ctx.baseUrl, DEMO.admin);
  assert.equal(res.status, 200);
  assert.equal(res.body.success, true);
  assert.ok(res.token);
  assert.ok(res.body.data.refreshToken);
  assert.equal(res.body.data.user.role, 'system_admin');
});

test('wrong password is rejected with 401', async () => {
  const res = await login(ctx.baseUrl, '0999999999', 'wrong-password');
  assert.equal(res.status, 401);
  assert.equal(res.body.success, false);
});

test('protected endpoints reject requests without a token', async () => {
  const res = await api(ctx.baseUrl, '/api/auth/me');
  assert.equal(res.status, 401);
});

test('GET /api/auth/me returns the authenticated user', async () => {
  const auth = await login(ctx.baseUrl, DEMO.citizen);
  assert.ok(auth.token);
  const res = await api(ctx.baseUrl, '/api/auth/me', { token: auth.token });
  assert.equal(res.status, 200);
  assert.equal(res.body.data.role, 'citizen');
  assert.equal(res.body.data.phone, DEMO.citizen);
});

test('public announcements are readable without a token', async () => {
  const res = await api(ctx.baseUrl, '/api/announcements');
  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
});
