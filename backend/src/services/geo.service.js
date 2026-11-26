const EARTH_RADIUS_M = 6371000;

export function haversine(lat1, lon1, lat2, lon2) {
  if ([lat1, lon1, lat2, lon2].some((value) =>
    value == null || value === '' || !Number.isFinite(Number(value)))) {
    return Infinity;
  }
  const toRad = (degrees) => (degrees * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a));
}

export function pointInPolygon(lat, lng, polygon) {
  if (!Array.isArray(polygon) || polygon.length < 3) return false;
  const points = polygon.map((point) => {
    if (Array.isArray(point) && point.length >= 2) {
      if (point[0] == null || point[1] == null || point[0] === '' || point[1] === '') {
        return { lat: NaN, lng: NaN };
      }
      return { lat: Number(point[0]), lng: Number(point[1]) };
    }
    if (point && typeof point === 'object') {
      const lat = point.lat ?? point.latitude;
      const lng = point.lng ?? point.longitude;
      if (lat == null || lng == null || lat === '' || lng === '') return { lat: NaN, lng: NaN };
      return {
        lat: Number(lat),
        lng: Number(lng),
      };
    }
    return { lat: NaN, lng: NaN };
  });
  if (points.some((point) => !Number.isFinite(point.lat) || !Number.isFinite(point.lng))) return false;

  let inside = false;
  for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
    const a = points[i];
    const b = points[j];
    const cross = (lng - a.lng) * (b.lat - a.lat) - (lat - a.lat) * (b.lng - a.lng);
    if (Math.abs(cross) < 1e-10
      && lng >= Math.min(a.lng, b.lng) && lng <= Math.max(a.lng, b.lng)
      && lat >= Math.min(a.lat, b.lat) && lat <= Math.max(a.lat, b.lat)) {
      return true;
    }
    if (((a.lat > lat) !== (b.lat > lat))
      && lng < ((b.lng - a.lng) * (lat - a.lat)) / (b.lat - a.lat) + a.lng) {
      inside = !inside;
    }
  }
  return inside;
}

export function isInsideGeofence(lat, lng, zone) {
  if (Array.isArray(zone.polygon) && zone.polygon.length >= 3) {
    return pointInPolygon(lat, lng, zone.polygon);
  }
  if (zone.center_lat == null || zone.center_lng == null || zone.radius_m == null) return false;
  const radius = Number(zone.radius_m);
  return Number.isFinite(radius) && radius > 0
    && haversine(lat, lng, zone.center_lat, zone.center_lng) <= radius;
}
