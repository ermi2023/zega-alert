import { useEffect, useRef, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle, Polygon, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { getMapTileConfig } from '../utils/mapTiles';

// OpenStreetMap via Leaflet - no API key and no billing. The map API key that
// Google Maps required (spec 4.4) is intentionally not used.
const DEFAULT_CENTER = [9.6, 38.75]; // Addis Ababa

const PIN_COLORS = { alert: '#ef4444', officer: '#22c55e' };
const pinCache = {};

// Round divIcon pins avoid Leaflet's default marker images (which break under
// bundlers) so no image assets are needed.
const pin = (kind) => {
  if (pinCache[kind]) return pinCache[kind];
  const color = PIN_COLORS[kind] || '#183C59';
  pinCache[kind] = L.divIcon({
    className: 'zega-pin',
    html: `<span style="display:block;width:14px;height:14px;border-radius:50%;background:${color};border:2px solid #fff;box-shadow:0 0 0 1px rgba(0,0,0,.4)"></span>`,
    iconSize: [14, 14],
    iconAnchor: [7, 7],
    popupAnchor: [0, -8],
  });
  return pinCache[kind];
};

const cssHeight = (h) => (typeof h === 'number' ? `${h}px` : h);

function polygonPositions(polygon) {
  if (!Array.isArray(polygon)) return [];
  return polygon.map((point) => (Array.isArray(point)
    ? [Number(point[0]), Number(point[1])]
    : [Number(point.lat ?? point.latitude), Number(point.lng ?? point.longitude)]));
}

function geofenceCenter(geofence) {
  const points = polygonPositions(geofence.polygon);
  if (points.length >= 3) {
    return [
      points.reduce((sum, point) => sum + point[0], 0) / points.length,
      points.reduce((sum, point) => sum + point[1], 0) / points.length,
    ];
  }
  if (geofence.center_lat == null || geofence.center_lng == null) return null;
  return [Number(geofence.center_lat), Number(geofence.center_lng)];
}

// Panels are laid out after mount, so the map needs a size recalculation.
function ResizeFix() {
  const map = useMap();
  useEffect(() => {
    const t = setTimeout(() => map.invalidateSize(), 250);
    return () => clearTimeout(t);
  }, [map]);
  return null;
}

// Recenter when the set of tracked entities changes (not on every GPS tick),
// so a newly arrived SOS is visible without fighting the operator's panning.
function FitBounds({ points, signature }) {
  const map = useMap();
  const pointsRef = useRef(points);
  useEffect(() => { pointsRef.current = points; }, [points]);
  useEffect(() => {
    const pts = pointsRef.current;
    if (!pts.length) return;
    if (pts.length === 1) map.setView(pts[0], 14);
    else map.fitBounds(pts, { padding: [40, 40], maxZoom: 15 });
  }, [map, signature]);
  return null;
}

export default function LiveMap({
  alerts = [],
  officers = [],
  geofences = [],
  height = 340,
  center,
  defaultCenter = DEFAULT_CENTER,
}) {
  const [satellite, setSatellite] = useState(false);
  const resolvedCenter =
    center ||
    (alerts[0] && [Number(alerts[0].latitude), Number(alerts[0].longitude)]) ||
    (officers[0] && [Number(officers[0].latitude), Number(officers[0].longitude)]) ||
    (geofences[0] && geofenceCenter(geofences[0])) ||
    defaultCenter;

  const fitPoints = [
    ...alerts.filter((s) => s.latitude && s.longitude).map((s) => [Number(s.latitude), Number(s.longitude)]),
    ...officers.filter((p) => p.latitude && p.longitude).map((p) => [Number(p.latitude), Number(p.longitude)]),
  ];
  const signature = `${alerts.map((a) => a.id).join(',')}|${officers.map((o) => o.userId).join(',')}`;
  const tileConfig = getMapTileConfig(satellite);

  return (
    <div style={{ width: '100%', height: cssHeight(height), borderRadius: 10, overflow: 'hidden', position: 'relative' }}>
      <MapContainer center={resolvedCenter} zoom={12} style={{ width: '100%', height: '100%' }} scrollWheelZoom>
        <TileLayer attribution={tileConfig.attribution} url={tileConfig.url} />
        <ResizeFix />
        <FitBounds points={fitPoints} signature={signature} />

        {geofences.filter((g) => g.polygon?.length >= 3 || (
          g.center_lat != null && g.center_lng != null && Number(g.radius_m) > 0
        )).map((g) => {
          const popup = (
            <Popup>
              <div style={{ fontSize: 13 }}>
                <b>{g.name}</b>
                <div>Type: {g.type}</div>
                <div>{g.region || '—'}</div>
                {g.polygon?.length >= 3 ? <div>Mapped boundary</div> : g.radius_m ? <div>{g.radius_m}m radius</div> : null}
              </div>
            </Popup>
          );
          return g.polygon?.length >= 3 ? (
            <Polygon
              key={`g-${g.id}`}
              positions={polygonPositions(g.polygon)}
              pathOptions={{ color: '#183C59', fillColor: '#183C59', fillOpacity: 0.15, weight: 1 }}
            >
              {popup}
            </Polygon>
          ) : (
            <Circle
              key={`g-${g.id}`}
              center={[Number(g.center_lat), Number(g.center_lng)]}
              radius={Number(g.radius_m)}
              pathOptions={{ color: '#183C59', fillColor: '#183C59', fillOpacity: 0.15, weight: 1 }}
            >
              {popup}
            </Circle>
          );
        })}

        {alerts.filter((s) => s.latitude && s.longitude).map((s) => (
          <Marker key={`a-${s.id}`} position={[Number(s.latitude), Number(s.longitude)]} icon={pin('alert')}>
            <Popup>
              <div style={{ fontSize: 13 }}>
                <b>{s.user_name || 'Citizen'}</b>
                <div>{s.address_text || 'No address'}</div>
                <div>Status: {s.status}</div>
              </div>
            </Popup>
          </Marker>
        ))}

        {officers.filter((p) => p.latitude && p.longitude).map((p) => (
          <Marker key={`o-${p.userId}`} position={[Number(p.latitude), Number(p.longitude)]} icon={pin('officer')}>
            <Popup>
              <div style={{ fontSize: 13 }}>
                <b>{p.userName || 'Officer'}</b>
                <div>{p.role || ''}</div>
                <div>updated {new Date(p.timestamp).toLocaleTimeString()}</div>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
      <button
        type="button"
        title={satellite ? 'Switch to street map' : 'Switch to satellite imagery'}
        aria-label={satellite ? 'Switch to street map' : 'Switch to satellite imagery'}
        onClick={() => setSatellite((current) => !current)}
        style={{
          position: 'absolute',
          top: 12,
          right: 12,
          zIndex: 1000,
          border: '1px solid #9ca3af',
          borderRadius: 6,
          background: '#fff',
          padding: '8px 12px',
          cursor: 'pointer',
        }}
      >
        {satellite ? 'Street map' : 'Satellite'}
      </button>
    </div>
  );
}
