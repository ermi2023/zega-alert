import assert from 'node:assert/strict';
import test from 'node:test';
import { isInsideGeofence, pointInPolygon } from '../src/services/geo.service.js';

test('circular zones use the configured radius', () => {
  const zone = { center_lat: 9, center_lng: 38, radius_m: 100 };
  assert.equal(isInsideGeofence(9, 38, zone), true);
  assert.equal(isInsideGeofence(9.01, 38, zone), false);
});

test('drawn boundaries take precedence over a circle', () => {
  const zone = {
    center_lat: 9,
    center_lng: 38,
    radius_m: 1000,
    polygon: [[0, 0], [0, 1], [1, 1], [1, 0]],
  };
  assert.equal(isInsideGeofence(0.5, 0.5, zone), true);
  assert.equal(isInsideGeofence(9, 38, zone), false);
});

test('polygon boundaries accept points on an edge and reject invalid shapes', () => {
  const square = [[0, 0], [0, 1], [1, 1], [1, 0]];
  assert.equal(pointInPolygon(0.5, 0, square), true);
  assert.equal(pointInPolygon(2, 2, square), false);
  assert.equal(pointInPolygon(0.5, 0.5, [[0, 0], ['bad', 1], [1, 1]]), false);
  assert.equal(pointInPolygon(0.5, 0.5, [[0, 0], [null, 1], [1, 1]]), false);
  assert.equal(isInsideGeofence(9, 38, { center_lat: 9, center_lng: 38, radius_m: 0 }), false);
});
