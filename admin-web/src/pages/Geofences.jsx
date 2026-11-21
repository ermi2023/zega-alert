import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Circle, CircleMarker, MapContainer, Polygon, TileLayer, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { api } from '../api/client';
import LiveMap from '../components/LiveMap';

const TYPES = ['zone', 'school', 'police_station', 'hospital', 'event', 'residence', 'market'];
const SENSITIVITIES = ['low', 'medium', 'high'];
const EMPTY_FORM = {
  name: '', label: '', type: 'zone', region: '', sub_city: '', woreda: '',
  center_lat: '', center_lng: '', radius_m: '300', sensitivity: 'medium',
  polygon: [], is_active: true,
};

function MapEditor({ form, drawMode, setForm }) {
  const center = useMemo(() => {
    const lat = Number(form.center_lat);
    const lng = Number(form.center_lng);
    return Number.isFinite(lat) && Number.isFinite(lng) ? [lat, lng] : [9.03, 38.74];
  }, [form.center_lat, form.center_lng]);

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
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {form.center_lat && form.center_lng && (
        <>
          <Circle
            center={[Number(form.center_lat), Number(form.center_lng)]}
            radius={Number(form.radius_m) || 300}
            pathOptions={{ color: '#2563eb', fillColor: '#2563eb', fillOpacity: 0.15 }}
          />
          <CircleMarker
            center={[Number(form.center_lat), Number(form.center_lng)]}
            radius={7}
            pathOptions={{ color: '#1d4ed8', fillColor: '#3b82f6', fillOpacity: 1 }}
          />
        </>
      )}
      {(form.polygon || []).length > 0 && (
        <Polygon positions={form.polygon} pathOptions={{ color: '#16a34a', fillColor: '#22c55e', fillOpacity: 0.2 }} />
      )}
    </>
  );
}

export default function Geofences() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [editing, setEditing] = useState(null);
  const [drawMode, setDrawMode] = useState(false);
  const [msg, setMsg] = useState({ type: '', text: '' });

  const load = () => api.get('/geofences').then(setRows);
  useEffect(() => { load(); }, []);

  const reset = () => {
    setEditing(null);
    setDrawMode(false);
    setForm({ ...EMPTY_FORM });
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
    setDrawMode(false);
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
      sensitivity: g.sensitivity || 'medium',
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
        <form onSubmit={submit}>
          <div className="form-row">
            <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
            <label>Label<input value={form.label} onChange={(e) => setForm({ ...form, label: e.target.value })} placeholder="e.g. Bole school zone" /></label>
            <label>{t('geofences.type')}
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                {TYPES.map((v) => <option key={v} value={v}>{v.replace('_', ' ')}</option>)}
              </select>
            </label>
            <label>Sensitivity
              <select value={form.sensitivity} onChange={(e) => setForm({ ...form, sensitivity: e.target.value })}>
                {SENSITIVITIES.map((v) => <option key={v} value={v}>{v}</option>)}
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

          <div style={{ display: 'flex', gap: 8, alignItems: 'center', margin: '12px 0', flexWrap: 'wrap' }}>
            <button type="button" className={`btn small ${drawMode ? '' : 'ghost'}`} onClick={() => setDrawMode(false)}>
              Set center on map
            </button>
            <button type="button" className={`btn small ${drawMode ? '' : 'ghost'}`} onClick={() => setDrawMode(true)}>
              Draw polygon
            </button>
            <button type="button" className="btn small ghost" onClick={() => setForm({ ...form, polygon: [] })}>
              Clear polygon
            </button>
            <span style={{ color: 'var(--muted)', fontSize: 12 }}>
              {drawMode ? 'Click the map to add polygon points.' : 'Click the map to move the centre.'}
              {' '}{form.polygon?.length || 0} point(s)
            </span>
          </div>
          <div style={{ height: 300, borderRadius: 10, overflow: 'hidden', marginBottom: 12 }}>
            <MapContainer
              center={[Number(form.center_lat) || 9.03, Number(form.center_lng) || 38.74]}
              zoom={14}
              style={{ width: '100%', height: '100%' }}
            >
              <MapEditor form={form} drawMode={drawMode} setForm={setForm} />
            </MapContainer>
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
          <thead><tr><th>{t('geofences.name')}</th><th>Label</th><th>{t('geofences.type')}</th><th>Sensitivity</th><th>{t('geofences.region')}</th><th>Center</th><th>Radius</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {rows.map((g) => (
              <tr key={g.id}>
                <td>{g.name}</td>
                <td>{g.label || '—'}</td>
                <td><span className="badge blue">{g.type}</span></td>
                <td><span className={`badge ${g.sensitivity === 'high' ? 'red' : g.sensitivity === 'low' ? 'gray' : 'amber'}`}>{g.sensitivity || 'medium'}</span></td>
                <td>{g.region || '—'}</td>
                <td>{g.center_lat ? `${Number(g.center_lat).toFixed(4)}, ${Number(g.center_lng).toFixed(4)}` : '—'}</td>
                <td>{g.radius_m ? `${g.radius_m}m` : '—'}</td>
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
            {rows.length === 0 && <tr><td colSpan={9} style={{ color: 'var(--muted)' }}>{t('geofences.none')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
