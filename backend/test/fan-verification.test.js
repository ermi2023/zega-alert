import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { startServer, endPool, api, login, DEMO } from './helpers.js';
import { pool } from '../src/config/db.js';

let ctx;

before(async () => {
  ctx = await startServer();
});

after(async () => {
  await ctx.close();
  await endPool();
});

test('identity verification requires an active admin FAN record', async () => {
  const admin = await login(ctx.baseUrl, DEMO.admin);
  assert.ok(admin.token);

  const suffix = Date.now().toString().slice(-8);
  const fanNumber = (8000000000000000n + BigInt(Date.now())).toString();
  let userId;
  let recordId;
  try {
    const createdUser = await api(ctx.baseUrl, '/api/admin/users', {
      method: 'POST',
      token: admin.token,
      body: {
        full_name: 'FAN verification test',
        phone: `09${suffix}`,
        password: 'T3stFan!Pass2026',
        role: 'citizen',
      },
    });
    assert.equal(createdUser.status, 201);
    userId = createdUser.body.data.id;
    const citizen = await login(ctx.baseUrl, `09${suffix}`, 'T3stFan!Pass2026');
    assert.ok(citizen.token);

    const createdRecord = await api(ctx.baseUrl, '/api/admin/fan-records', {
      method: 'POST',
      token: admin.token,
      body: {
        full_name: 'Mock Citizen',
        phone: `09${suffix}`,
        fan_number: fanNumber,
      },
    });
    assert.equal(createdRecord.status, 201);
    recordId = createdRecord.body.data.id;

    const denied = await api(ctx.baseUrl, '/api/admin/fan-records', {
      token: citizen.token,
    });
    assert.equal(denied.status, 403);

    let unmatchedFan = (BigInt(fanNumber) + 1n).toString().padStart(16, '0');
    while ((await pool.query(
      'SELECT 1 FROM fan_verification_records WHERE fan_number = $1',
      [unmatchedFan],
    )).rows.length) {
      unmatchedFan = (BigInt(unmatchedFan) + 1n).toString().padStart(16, '0');
    }
    const unmatched = await api(ctx.baseUrl, '/api/verification/fan', {
      method: 'POST',
      token: citizen.token,
      body: { fan_number: unmatchedFan },
    });
    assert.equal(unmatched.status, 200);
    assert.equal(unmatched.body.data.status, 'not_verified');

    const unmatchedQr = await api(ctx.baseUrl, '/api/verification/qr', {
      method: 'POST',
      token: citizen.token,
      body: {
        qr_data: JSON.stringify({ FIN: unmatchedFan, full_name: 'Original ID Name' }),
      },
    });
    assert.equal(unmatchedQr.body.data.status, 'not_verified');
    assert.equal(unmatchedQr.body.data.mock_record, null);

    await api(ctx.baseUrl, `/api/admin/fan-records/${recordId}`, {
      method: 'PATCH',
      token: admin.token,
      body: { is_active: false },
    });
    const inactive = await api(ctx.baseUrl, '/api/verification/fan', {
      method: 'POST',
      token: citizen.token,
      body: { fan_number: fanNumber },
    });
    assert.equal(inactive.body.data.status, 'not_verified');

    await api(ctx.baseUrl, `/api/admin/fan-records/${recordId}`, {
      method: 'PATCH',
      token: admin.token,
      body: { is_active: true },
    });
    const matched = await api(ctx.baseUrl, '/api/verification/qr', {
      method: 'POST',
      token: citizen.token,
      body: {
        qr_data: JSON.stringify({
          FIN: fanNumber,
          full_name: 'Name from original ID QR',
          phone: '0999999999',
        }),
      },
    });
    assert.equal(matched.body.data.status, 'verified');
    assert.deepEqual(matched.body.data.mock_record, {
      full_name: 'Mock Citizen',
      phone: `09${suffix}`,
      fan_number: fanNumber,
    });
    assert.equal(JSON.stringify(matched.body.data).includes('Name from original ID QR'), false);

    const repeated = await api(ctx.baseUrl, '/api/verification/fan', {
      method: 'POST',
      token: citizen.token,
      body: { fan_number: fanNumber },
    });
    assert.deepEqual(repeated.body.data.mock_record, matched.body.data.mock_record);

    const status = await api(ctx.baseUrl, '/api/verification/status', {
      token: citizen.token,
    });
    assert.equal(status.body.data.verified, true);
  } finally {
    if (recordId) {
      await pool.query('DELETE FROM fan_verification_records WHERE id = $1', [recordId]);
    }
    if (userId) await pool.query('DELETE FROM users WHERE id = $1', [userId]);
  }
});
