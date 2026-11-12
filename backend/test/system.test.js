import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { startServer, endPool, api } from './helpers.js';

let ctx;

before(async () => {
  ctx = await startServer();
});

after(async () => {
  await ctx.close();
  await endPool();
});

test('GET /health reports the API is up', async () => {
  const res = await api(ctx.baseUrl, '/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.ok, true);
});

test('GET / exposes the app name and running status', async () => {
  const res = await api(ctx.baseUrl, '/');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'running');
  assert.ok(res.body.name);
});

test('unknown routes return a JSON 404 envelope', async () => {
  const res = await api(ctx.baseUrl, '/api/definitely-not-a-route');
  assert.equal(res.status, 404);
  assert.equal(res.body.success, false);
  assert.match(res.body.message, /Route not found/);
});

test('malformed JSON is rejected with a clean 400 (no crash)', async () => {
  const res = await api(ctx.baseUrl, '/api/auth/login', { method: 'POST', rawBody: '{bad json}' });
  assert.equal(res.status, 400);
  assert.equal(res.body.success, false);
  assert.match(res.body.message, /JSON/i);

  // Server must still be healthy after the bad request.
  const health = await api(ctx.baseUrl, '/health');
  assert.equal(health.status, 200);
});
