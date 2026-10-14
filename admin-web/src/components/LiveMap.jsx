import { useState } from 'react';
import { GoogleMap, useJsApiLoader, Marker, InfoWindow, Circle } from '@react-google-maps/api';

const containerStyle = (height) => ({ width: '100%', height, borderRadius: 10 });
const DEFAULT_CENTER = { lat: 9.6, lng: 38.75 }; // Addis Ababa

function NoKey({ height, text }) {
  return (
    <div
      style={{ ...containerStyle(height), background: '#1b2436', color: 'var(--muted)', display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: 20, fontSize: 13 }}
    >
      <div>
        <div style={{ fontSize: 22, marginBottom: 6 }}>🗺</div>
        {text || 'Google Maps API key not configured.'}
        <div style={{ marginTop: 8, fontSize: 12 }}>
          Set <code>VITE_GOOGLE_MAPS_API_KEY</code> to enable the live map.
        </div>
      </div>
    </div>
  );
}

export default function LiveMap({
  alerts = [],
  officers = [],
  geofences = [],
  height = 340,
  center,
  defaultCenter = DEFAULT_CENTER,
}) {
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';
  const { isLoaded, loadError } = useJsApiLoader({
    id: 'zega-google-map',
    googleMapsApiKey: apiKey,
  });
  const [selected, setSelected] = useState(null);

  const resolvedCenter =
    center ||
    (alerts[0] && { lat: Number(alerts[0].latitude), lng: Number(alerts[0].longitude) }) ||
    (officers[0] && { lat: Number(officers[0].latitude), lng: Number(officers[0].longitude) }) ||
    (geofences[0] && { lat: Number(geofences[0].center_lat), lng: Number(geofences[0].center_lng) }) ||
    defaultCenter;

  if (!apiKey) return <NoKey height={height} />;
  if (loadError) return <NoKey height={height} text="Google Maps failed to load (check the API key / network)." />;
  if (!isLoaded) {
    return (
      <div style={{ ...containerStyle(height), background: '#1b2436', color: 'var(--muted)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        Loading map…
      </div>
    );
  }

  const selPos = selected && {
    lat: Number(selected.latitude ?? selected.center_lat),
    lng: Number(selected.longitude ?? selected.center_lng),
  };

  return (
    <GoogleMap mapContainerStyle={containerStyle(height)} center={resolvedCenter} zoom={12}>
      {geofences.filter((g) => g.center_lat && g.center_lng).map((g) => (
        <Circle
          key={`g-${g.id}`}
          center={{ lat: Number(g.center_lat), lng: Number(g.center_lng) }}
          radius={Number(g.radius_m) || 300}
          options={{ strokeColor: '#2563eb', fillColor: '#2563eb', fillOpacity: 0.15, strokeWeight: 1 }}
          onClick={() => setSelected({ latitude: g.center_lat, longitude: g.center_lng, title: g.name, lines: [`Type: ${g.type}`, g.region || '—', g.radius_m ? `${g.radius_m}m radius` : ''] })}
        />
      ))}
      {alerts.filter((s) => s.latitude && s.longitude).map((s) => (
        <Marker
          key={`a-${s.id}`}
          position={{ lat: Number(s.latitude), lng: Number(s.longitude) }}
          onClick={() => setSelected({ latitude: s.latitude, longitude: s.longitude, title: s.user_name || 'Citizen', lines: [s.address_text || 'No address', `Status: ${s.status}`] })}
        />
      ))}
      {officers.filter((p) => p.latitude && p.longitude).map((p) => (
        <Marker
          key={`o-${p.userId}`}
          position={{ lat: Number(p.latitude), lng: Number(p.longitude) }}
          onClick={() => setSelected({ latitude: p.latitude, longitude: p.longitude, title: p.userName || 'Officer', lines: [`${p.role || ''}`, `updated ${new Date(p.timestamp).toLocaleTimeString()}`] })}
        />
      ))}
      {selected && selPos && (
        <InfoWindow position={selPos} onCloseClick={() => setSelected(null)}>
          <div style={{ fontSize: 13, minWidth: 120 }}>
            <b>{selected.title}</b>
            {selected.lines.filter(Boolean).map((l, i) => <div key={i}>{l}</div>)}
          </div>
        </InfoWindow>
      )}
    </GoogleMap>
  );
}
