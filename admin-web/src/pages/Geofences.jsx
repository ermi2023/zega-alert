import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Circle, CircleMarker, MapContainer, Polygon, Polyline, TileLayer, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { api } from '../api/client';
import LiveMap from '../components/LiveMap';
import { getMapTileConfig } from '../utils/mapTiles';

const TYPES = ['zone', 'school', 'police_station', 'hospital', 'event', 'residence', 'market'];
const EMPTY_FORM = {
  name: '', label: '', type: 'zone', region: '', sub_city: '', woreda: '',
  center_lat: '', center_lng: '', radius_m: '300',
  polygon: [], is_active: true,
};

function MapEditor({ form, drawMode, setForm, satellite }) {
  const tileConfig = getMapTileConfig(satellite);
  useMapEvents({
    click(e) {
      if (drawMode) {
        setForm((f) => ({ ...f, polygon: [...(f.polygon || []), [e.latlng.lat, e.latlng.lng]] }));
      } else {
        setForm((f) => ({ ...f, center_lat: e.latlng.lat.toFixed(6), center_lng: e.latlng.lng.toFixed(6) }));
      }
    },
  });

  return (
    <>
      <TileLayer attribution={tileConfig.attribution} url={tileConfig.url} />
      {!drawMode && (form.polygon || []).length < 3 && form.center_lat && form.center_lng && (
        <>
          <Circle
            center={[Number(form.center_lat), Number(form.center_lng)]}
            radius={Number(form.radius_m) || 300}
            pathOptions={{ color: '#2563eb', fillColor: '#2563eb', fillOpacity: 0.15 }}
          />
          {(form.polygon || []).length < 3 && (
            <CircleMarker
              center={[Number(form.center_lat), Number(form.center_lng)]}
              radius={7}
              pathOptions={{ color: '#1d4ed8', fillColor: '#3b82f6', fillOpacity: 1 }}
            />
          )}
        </>
      )}
      {(form.polygon || []).length >= 3 && (
        <Polygon positions={form.polygon} pathOptions={{ color: '#16a34a', fillColor: '#22c55e', fillOpacity: 0.2 }} />
      )}
      {drawMode && (form.polygon || []).length >= 2 && (form.polygon || []).length < 3 && (
        <Polyline positions={form.polygon} pathOptions={{ color: '#16a34a' }} />
      )}
    </>
  );
}

function MapView({ center, zoom }) {
  const map = useMap();
  useEffect(() => {
    map.setView(center, zoom);
  }, [center, map, zoom]);
  return null;
}

function MapResizeFix() {
  const map = useMap();
  useEffect(() => {
    const timer = window.setTimeout(() => map.invalidateSize(), 100);
    return () => window.clearTimeout(timer);
  }, [map]);
  return null;
}

function pickerCenter(form) {
  const lat = Number(form.center_lat);
  const lng = Number(form.center_lng);
  if (form.center_lat !== '' && form.center_lng !== '' && Number.isFinite(lat) && Number.isFinite(lng)) {
    return [lat, lng];
  }
  if (form.polygon?.length >= 3) {
    return [
      form.polygon.reduce((sum, point) => sum + Number(Array.isArray(point) ? point[0] : point.lat ?? point.latitude), 0) / form.polygon.length,
      form.polygon.reduce((sum, point) => sum + Number(Array.isArray(point) ? point[1] : point.lng ?? point.longitude), 0) / form.polygon.length,
    ];
  }
  return [9.03, 38.74];
}

export default function Geofences() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [editing, setEditing] = useState(null);
  const [drawMode, setDrawMode] = useState(false);
  const [satellite, setSatellite] = useState(false);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [mapOpen, setMapOpen] = useState(false);
  const [mapCenter, setMapCenter] = useState([9.03, 38.74]);
  const [mapSearch, setMapSearch] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [searchError, setSearchError] = useState('');
  const [searching, setSearching] = useState(false);
  const [mapSnapshot, setMapSnapshot] = useState(null);
  const lastSearchAt = useRef(0);

  const load = () => api.get('/geofences').then(setRows);
  useEffect(() => { load(); }, []);

  const reset = () => {
    setEditing(null);
    setDrawMode(false);
    setMapOpen(false);
    setMapSnapshot(null);
    setForm({ ...EMPTY_FORM });
  };

  const openMap = () => {
    const editingBoundary = (form.polygon || []).length >= 3;
    setDrawMode(editingBoundary);
    setMapSnapshot({
      center_lat: form.center_lat,
      center_lng: form.center_lng,
      region: form.region,
      polygon: [...(form.polygon || [])],
      drawMode: editingBoundary,
    });
    setMapCenter(pickerCenter(form));
    setMapSearch(form.region || '');
    setSearchResults([]);
    setSearchError('');
    setMapOpen(true);
  };

  const closeMap = (save) => {
    if (!save && mapSnapshot) {
      setForm((current) => ({
        ...current,
        center_lat: mapSnapshot.center_lat,
        center_lng: mapSnapshot.center_lng,
        region: mapSnapshot.region,
        polygon: mapSnapshot.polygon,
      }));
      setDrawMode(mapSnapshot.drawMode);
    }
    setMapSnapshot(null);
    setMapOpen(false);
    setSearchResults([]);
  };

  useEffect(() => {
    if (!mapOpen) return undefined;
    const handleEscape = (event) => {
      if (event.key === 'Escape' && mapSnapshot) {
        setForm((current) => ({
          ...current,
          center_lat: mapSnapshot.center_lat,
          center_lng: mapSnapshot.center_lng,
          region: mapSnapshot.region,
          polygon: mapSnapshot.polygon,
        }));
        setDrawMode(mapSnapshot.drawMode);
        setMapSnapshot(null);
        setMapOpen(false);
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [mapOpen, mapSnapshot]);

  const searchMap = async (event) => {
    event.preventDefault();
    const searchText = mapSearch.trim();
    if (!searchText || searching) return;

    setSearching(true);
    setSearchError('');
    setSearchResults([]);
    try {
      const delay = Math.max(0, 1000 - (Date.now() - lastSearchAt.current));
      if (delay) await new Promise((resolve) => window.setTimeout(resolve, delay));
      lastSearchAt.current = Date.now();
      const params = new URLSearchParams({
        q: `${searchText}, Ethiopia`,
        format: 'jsonv2',
        addressdetails: '1',
        countrycodes: 'et',
        limit: '5',
      });
      const response = await fetch(`https://nominatim.openstreetmap.org/search?${params}`);
      if (!response.ok) throw new Error(`Location search failed (${response.status}).`);
      const results = await response.json();
      if (!Array.isArray(results) || results.length === 0) {
        setSearchError('No matching place found in Ethiopia. Try another name.');
      } else {
        setSearchResults(results);
      }
    } catch (error) {
      setSearchError(error.message || 'Could not search for this place.');
    } finally {
      setSearching(false);
    }
  };

  const selectSearchResult = (result) => {
    const center = [Number(result.lat), Number(result.lon)];
    if (!center.every(Number.isFinite)) {
      setSearchError('This search result has no map location. Try another result.');
      return;
    }
    setMapCenter(center);
    setSearchResults([]);
    setMapSearch(result.display_name);
    const region = result.address?.state;
    setForm((current) => ({
      ...current,
      region: current.region || region || '',
      ...(drawMode ? {} : {
        center_lat: center[0].toFixed(6),
        center_lng: center[1].toFixed(6),
      }),
    }));
  };

  const submit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      center_lat: form.center_lat === '' ? null : Number(form.center_lat),
      center_lng: form.center_lng === '' ? null : Number(form.center_lng),
      radius_m: form.radius_m === '' ? null : Number(form.radius_m),
      polygon: form.polygon || [],
    };
    try {
      if (editing) await api.patch(`/geofences/${editing}`, payload);
      else await api.post('/geofences', payload);
      setMsg({ type: 'ok', text: editing ? 'Geofence updated.' : t('geofences.created') });
      reset();
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const edit = (g) => {
    setEditing(g.id);
    setDrawMode(Array.isArray(g.polygon) && g.polygon.length >= 3);
    setForm({
      name: g.name || '',
      label: g.label || '',
      type: g.type || 'zone',
      region: g.region || '',
      sub_city: g.sub_city || '',
      woreda: g.woreda || '',
      center_lat: g.center_lat ?? '',
      center_lng: g.center_lng ?? '',
      radius_m: g.radius_m ?? '',
      polygon: Array.isArray(g.polygon) ? g.polygon : [],
      is_active: g.is_active !== false,
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const toggleActive = async (g) => {
    await api.patch(`/geofences/${g.id}`, { is_active: !g.is_active });
    load();
  };

  const remove = async (id) => {
    if (!window.confirm('Delete this geofence?')) return;
    await api.del(`/geofences/${id}`);
    if (editing === id) reset();
    load();
  };

  return (
    <div>
      <div className="page-head"><div><h1>{t('geofences.title')}</h1><p>{t('geofences.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel">
        <h2>{editing ? 'Edit geofence' : t('geofences.newGeofence')}</h2>
        <p>These are public areas verified by authorized staff. An SOS inside an active area is highlighted for emergency staff; it does not guarantee safety.</p>
        <form onSubmit={submit}>
          <div className="form-row">
            <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
            <label>Label<input value={form.label} onChange={(e) => setForm({ ...form, label: e.target.value })} placeholder="e.g. Bole school zone" /></label>
            <label>{t('geofences.type')}
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                {TYPES.map((v) => <option key={v} value={v}>{v.replace('_', ' ')}</option>)}
              </select>
            </label>
          </div>
          <div className="form-row">
            <label>{t('geofences.region')}<input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} /></label>
            <label>{t('geofences.subCity')}<input value={form.sub_city} onChange={(e) => setForm({ ...form, sub_city: e.target.value })} /></label>
            <label>Woreda<input value={form.woreda} onChange={(e) => setForm({ ...form, woreda: e.target.value })} /></label>
          </div>
          <div className="form-row">
            <label>{t('geofences.centerLat')}<input value={form.center_lat} onChange={(e) => setForm({ ...form, center_lat: e.target.value })} /></label>
            <label>{t('geofences.centerLng')}<input value={form.center_lng} onChange={(e) => setForm({ ...form, center_lng: e.target.value })} /></label>
            <label>{t('geofences.radius')}<input type="number" min="50" value={form.radius_m} onChange={(e) => setForm({ ...form, radius_m: e.target.value })} /></label>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 24 }}>
              <input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} />
              Active
            </label>
          </div>

          <div className="panel" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap', margin: '12px 0' }}>
            <div>
              <strong>Map location</strong>
              <div style={{ color: 'var(--muted)', fontSize: 12 }}>
                {form.polygon?.length >= 3
                  ? `Mapped boundary · ${form.polygon.length} points`
                  : form.center_lat !== '' && form.center_lng !== ''
                    ? `Center ${Number(form.center_lat).toFixed(5)}, ${Number(form.center_lng).toFixed(5)} · ${form.radius_m || 300} m radius`
                    : 'No location selected yet'}
              </div>
            </div>
            <button type="button" className="btn" onClick={openMap}>Choose on full-screen map</button>
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn">{editing ? 'Save changes' : t('geofences.create')}</button>
            {editing && <button type="button" className="btn ghost" onClick={reset}>Cancel</button>}
          </div>
        </form>
      </div>

      <div className="panel">
        <h2>Map</h2>
        <LiveMap geofences={rows} height={340} />
      </div>

      <div className="panel">
        <h2>{t('geofences.zones')}</h2>
        <table>
          <thead><tr><th>{t('geofences.name')}</th><th>Label</th><th>{t('geofences.type')}</th><th>{t('geofences.region')}</th><th>Center</th><th>Boundary</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {rows.map((g) => (
              <tr key={g.id}>
                <td>{g.name}</td>
                <td>{g.label || '—'}</td>
                <td><span className="badge blue">{g.type}</span></td>
                <td>{g.region || '—'}</td>
                <td>{g.polygon?.length >= 3 ? '—' : g.center_lat != null && g.center_lng != null ? `${Number(g.center_lat).toFixed(4)}, ${Number(g.center_lng).toFixed(4)}` : '—'}</td>
                <td>{g.polygon?.length >= 3 ? 'Mapped boundary' : g.radius_m ? `${g.radius_m}m radius` : '—'}</td>
                <td>
                  <button className={`btn small ${g.is_active ? '' : 'ghost'}`} onClick={() => toggleActive(g)}>
                    {g.is_active ? 'Active' : 'Paused'}
                  </button>
                </td>
                <td style={{ whiteSpace: 'nowrap' }}>
                  <button className="btn small ghost" onClick={() => edit(g)}>Edit</button>
                  <button className="btn small danger" onClick={() => remove(g.id)}>{t('geofences.delete')}</button>
                </td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={8} style={{ color: 'var(--muted)' }}>{t('geofences.none')}</td></tr>}
          </tbody>
        </table>
      </div>
      {mapOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Choose safety-area location"
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 3000,
            display: 'flex',
            flexDirection: 'column',
            background: '#fff',
          }}
        >
          <div style={{ padding: 12, boxShadow: '0 2px 8px rgba(0,0,0,.15)', zIndex: 1 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, marginBottom: 10 }}>
              <strong>Choose area on map</strong>
              <button type="button" className="btn small ghost" onClick={() => closeMap(false)}>Cancel</button>
            </div>
            <form onSubmit={searchMap} style={{ display: 'flex', gap: 8 }}>
              <input
                aria-label="Search a region or place in Ethiopia"
                placeholder="Search a region or place in Ethiopia"
                value={mapSearch}
                onChange={(event) => {
                  setMapSearch(event.target.value);
                  setSearchResults([]);
                  setSearchError('');
                }}
                style={{ flex: 1, minWidth: 0 }}
              />
              <button className="btn" disabled={searching || !mapSearch.trim()}>
                {searching ? 'Searching…' : 'Search'}
              </button>
            </form>
            <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 4 }}>
              Search results and street maps © OpenStreetMap contributors; satellite imagery © Esri.
            </div>
            {searchError && <div className="msg err" style={{ marginTop: 8 }}>{searchError}</div>}
            {searchResults.length > 0 && (
              <div style={{ maxHeight: 150, overflowY: 'auto', border: '1px solid #ddd', borderRadius: 6, marginTop: 8 }}>
                {searchResults.map((result) => (
                  <button
                    key={result.place_id}
                    type="button"
                    onClick={() => selectSearchResult(result)}
                    style={{ display: 'block', width: '100%', padding: 10, textAlign: 'left', border: 0, borderBottom: '1px solid #eee', background: '#fff', cursor: 'pointer' }}
                  >
                    {result.display_name}
                  </button>
                ))}
              </div>
            )}
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 10, flexWrap: 'wrap' }}>
              <button type="button" className={`btn small ${drawMode ? 'ghost' : ''}`} onClick={() => {
                setDrawMode(false);
                setForm((current) => ({ ...current, polygon: [] }));
              }}>
                Set circular area
              </button>
              <button type="button" className={`btn small ${drawMode ? '' : 'ghost'}`} onClick={() => {
                setDrawMode(true);
                setForm((current) => ({ ...current, polygon: [] }));
              }}>
                Draw boundary
              </button>
              <button type="button" className="btn small ghost" onClick={() => setForm((current) => ({ ...current, polygon: [] }))}>
                Clear boundary
              </button>
              <span style={{ color: 'var(--muted)', fontSize: 12 }}>
                {drawMode ? `Tap at least 3 points (${form.polygon?.length || 0} selected).` : 'Tap the map to set the center.'}
              </span>
              <span style={{ color: 'var(--muted)', fontSize: 12 }}>
                Zoom changes only the view. Drawn points stay at fixed GPS coordinates; a circle keeps its set radius in meters.
              </span>
            </div>
          </div>
          <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
            <MapContainer
              center={mapCenter}
              zoom={14}
              style={{ width: '100%', height: '100%' }}
              scrollWheelZoom
            >
              <MapView center={mapCenter} zoom={14} />
              <MapResizeFix />
              <MapEditor
                form={form}
                drawMode={drawMode}
                setForm={setForm}
                satellite={satellite}
              />
            </MapContainer>
            <button
              type="button"
              className="btn small"
              title={satellite ? 'Switch to street map' : 'Switch to satellite imagery'}
              aria-label={satellite ? 'Switch to street map' : 'Switch to satellite imagery'}
              onClick={() => setSatellite((current) => !current)}
              style={{ position: 'absolute', top: 12, right: 12, zIndex: 1000 }}
            >
              {satellite ? 'Street map' : 'Satellite'}
            </button>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, padding: 12, boxShadow: '0 -2px 8px rgba(0,0,0,.12)' }}>
            <span style={{ fontSize: 12, color: 'var(--muted)' }}>
              {form.polygon?.length >= 3
                ? `Boundary: ${form.polygon.length} points`
                : form.center_lat !== '' && form.center_lng !== ''
                  ? `Center: ${Number(form.center_lat).toFixed(5)}, ${Number(form.center_lng).toFixed(5)}`
                  : 'Choose a map location'}
            </span>
            <button type="button" className="btn" onClick={() => closeMap(true)}>Use this location</button>
          </div>
        </div>
      )}
    </div>
  );
}
