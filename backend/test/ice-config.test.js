import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildIceServers } from '../src/services/ice-config.service.js';

test('buildIceServers returns public STUN servers when TURN is not configured', () => {
  const servers = buildIceServers({});

  assert.deepEqual(servers, [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
  ]);
});

test('buildIceServers adds configured TURN relays with credentials', () => {
  const servers = buildIceServers({
    turnUrls: ['turn:relay.example.test:3478?transport=udp', 'turns:relay.example.test:5349'],
    turnUsername: 'zega',
    turnCredential: 'relay-secret',
  });

  assert.deepEqual(servers.slice(2), [
    {
      urls: 'turn:relay.example.test:3478?transport=udp',
      username: 'zega',
      credential: 'relay-secret',
    },
    {
      urls: 'turns:relay.example.test:5349',
      username: 'zega',
      credential: 'relay-secret',
    },
  ]);
});

test('buildIceServers rejects incomplete TURN configuration', () => {
  assert.throws(
    () => buildIceServers({ turnUrls: ['turn:relay.example.test:3478'] }),
    /TURN_URLS, TURN_USERNAME, and TURN_CREDENTIAL/,
  );
});
