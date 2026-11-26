import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { startServer, endPool, api, login, DEMO } from './helpers.js';
import { pool } from '../src/config/db.js';

let ctx;
let citizenToken;
let otherCitizenToken;
let adminToken;
const createdIds = [];

before(async () => {
  ctx = await startServer();
  citizenToken = (await login(ctx.baseUrl, DEMO.citizen)).token;
  otherCitizenToken = (await login(ctx.baseUrl, DEMO.citizen2)).token;
  adminToken = (await login(ctx.baseUrl, DEMO.admin)).token;
  assert.ok(citizenToken && otherCitizenToken && adminToken, 'demo accounts must be seeded');
});

after(async () => {
  if (createdIds.length) {
    await pool.query('DELETE FROM reports WHERE id = ANY($1)', [createdIds]).catch(() => {});
  }
  await ctx.close();
  await endPool();
});

test('citizen can submit a crime report', async () => {
  const res = await api(ctx.baseUrl, '/api/reports', {
    method: 'POST',
    token: citizenToken,
    body: {
      category: 'theft',
      title: 'Automated test report',
      description: 'Created by the backend test suite',
      address_text: 'Dire Dawa, Test Zone',
      region: 'Dire Dawa',
    },
  });
  assert.equal(res.status, 201);
  assert.equal(res.body.success, true);
  assert.ok(res.body.data.id);
  createdIds.push(res.body.data.id);
});

test('citizen sees the report in their own list', async () => {
  const res = await api(ctx.baseUrl, '/api/reports/mine', { token: citizenToken });
  assert.equal(res.status, 200);
  const ids = res.body.data.map((r) => r.id);
  assert.ok(ids.some((id) => createdIds.includes(id)));
});

test('report status can be read with a valid id', async () => {
  const id = createdIds[0];
  const res = await api(ctx.baseUrl, `/api/reports/${id}`, { token: citizenToken });
  assert.equal(res.status, 200);
  assert.equal(res.body.data.id, id);
});

test('citizen cannot read another citizen report', async () => {
  const id = createdIds[0];
  const res = await api(ctx.baseUrl, `/api/reports/${id}`, { token: otherCitizenToken });
  assert.equal(res.status, 403);
});

test('citizen is not allowed to change report status (RBAC)', async () => {
  const id = createdIds[0];
  const res = await api(ctx.baseUrl, `/api/reports/${id}/status`, {
    method: 'PATCH',
    token: citizenToken,
    body: { status: 'under_review' },
  });
  assert.equal(res.status, 403);
});

test('staff can change report status', async () => {
  const id = createdIds[0];
  const res = await api(ctx.baseUrl, `/api/reports/${id}/status`, {
    method: 'PATCH',
    token: adminToken,
    body: { status: 'under_review', notes: 'Triaged by automated test' },
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.data.status, 'under_review');
});

test('invalid report id returns 400', async () => {
  const res = await api(ctx.baseUrl, '/api/reports/not-a-uuid', { token: adminToken });
  assert.equal(res.status, 400);
});
