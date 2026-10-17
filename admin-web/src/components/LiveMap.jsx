import { useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// OpenStreetMap via Leaflet - no API key and no billing. The map API key that
// Google Maps required (spec 4.4) is intentionally not used.
const DEFAULT_CENTER = [9.6, 38.75]; // Addis Ababa

const PIN_COLORS = { alert: '#ef4444', officer: '#22c55e' };
const pinCache = {};

// Round divIcon pins avoid Leaflet's default marker images (which break under
// bundlers) so no image assets are needed.
const pin = (kind) => {
  if (pinCache[kind]) return pinCache[kind];
  const color = PIN_COLORS[kind] || '#2563eb';
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

// Panels are laid out after mount, so the map needs a size recalculation.
function ResizeFix() {
  const map = useMap();
  useEffect(() => {
    const t = setTimeout(() => map.invalidateSize(), 250);
    return () => clearTimeout(t);
  }, [map]);
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
  const resolvedCenter =
    center ||
    (alerts[0] && [Number(alerts[0].latitude), Number(alerts[0].longitude)]) ||
    (officers[0] && [Number(officers[0].latitude), Number(officers[0].longitude)]) ||
    (geofences[0] && [Number(geofences[0].center_lat), Number(geofences[0].center_lng)]) ||
    defaultCenter;

  return (
    <div style={{ width: '100%', height: cssHeight(height), borderRadius: 10, overflow: 'hidden' }}>
      <MapContainer center={resolvedCenter} zoom={12} style={{ width: '100%', height: '100%' }} scrollWheelZoom>
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <ResizeFix />

        {geofences.filter((g) => g.center_lat && g.center_lng).map((g) => (
          <Circle
            key={`g-${g.id}`}
            center={[Number(g.center_lat), Number(g.center_lng)]}
            radius={Number(g.radius_m) || 300}
            pathOptions={{ color: '#2563eb', fillColor: '#2563eb', fillOpacity: 0.15, weight: 1 }}
          >
            <Popup>
              <div style={{ fontSize: 13 }}>
                <b>{g.name}</b>
                <div>Type: {g.type}</div>
                <div>{g.region || '—'}</div>
                {g.radius_m ? <div>{g.radius_m}m radius</div> : null}
              </div>
            </Popup>
          </Circle>
        ))}

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
    </div>
  );
}
