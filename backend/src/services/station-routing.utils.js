import { haversine } from './geo.service.js';

export function nearestStationByLocation(latitude, longitude, stations) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (
    latitude == null || longitude == null || latitude === '' || longitude === '' ||
    !Number.isFinite(lat) || !Number.isFinite(lng) ||
    lat < -90 || lat > 90 || lng < -180 || lng > 180
  ) {
    return null;
  }

  let nearest = null;
  for (const station of stations) {
    const stationLat = Number(station.latitude);
    const stationLng = Number(station.longitude);
    if (
      !Number.isFinite(stationLat) || !Number.isFinite(stationLng) ||
      stationLat < -90 || stationLat > 90 || stationLng < -180 || stationLng > 180
    ) {
      continue;
    }
    const distance = haversine(lat, lng, stationLat, stationLng);
    if (Number.isFinite(distance) && (!nearest || distance < nearest.distance_m)) {
      nearest = { ...station, distance_m: Math.round(distance) };
    }
  }
  return nearest;
}

export function selectRouteRecipients(stationUserIds, dispatcherIds) {
  return stationUserIds.length
    ? { userIds: stationUserIds, route: 'nearest_station' }
    : { userIds: dispatcherIds, route: 'central_dispatch' };
}
