import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  nearestStationByLocation,
  selectRouteRecipients,
} from '../src/services/station-routing.utils.js';

test('nearest station selection uses location distance', () => {
  const stations = [
    { id: 'far', latitude: 1, longitude: 1 },
    { id: 'near', latitude: 0.1, longitude: 0.1 },
  ];

  assert.equal(nearestStationByLocation(0, 0, stations).id, 'near');
});

test('nearest station selection returns null for invalid coordinates or no stations', () => {
  assert.equal(nearestStationByLocation(null, 0, [{ latitude: 0, longitude: 0 }]), null);
  assert.equal(nearestStationByLocation('', 0, [{ latitude: 0, longitude: 0 }]), null);
  assert.equal(nearestStationByLocation(91, 0, [{ latitude: 0, longitude: 0 }]), null);
  assert.equal(nearestStationByLocation(0, 0, []), null);
});

test('route recipients stay with station officers when present', () => {
  assert.deepEqual(selectRouteRecipients(['officer-1'], ['dispatcher-1']), {
    userIds: ['officer-1'],
    route: 'nearest_station',
  });
});

test('route falls back only to central dispatch when no station officers exist', () => {
  assert.deepEqual(selectRouteRecipients([], ['dispatcher-1']), {
    userIds: ['dispatcher-1'],
    route: 'central_dispatch',
  });
});
