import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

export default function Geofences() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState({ name: '', type: 'zone', region: '', sub_city: '', woreda: '', center_lat: '', center_lng: '', radius_m: '' });
  const [msg, setMsg] = useState({ type: '', text: '' });

  const load = () => api.get('/geofences').then(setRows);
  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    try {
      await api.post('/geofences', { ...form, center_lat: form.center_lat ? +form.center_lat : null, center_lng: form.center_lng ? +form.center_lng : null, radius_m: form.radius_m ? +form.radius_m : null });
      setMsg({ type: 'ok', text: t('geofences.created') });
      setForm({ name: '', type: 'zone', region: '', sub_city: '', woreda: '', center_lat: '', center_lng: '', radius_m: '' });
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const remove = async (id) => { await api.del(`/geofences/${id}`); load(); };

  return (
    <div>
      <div className="page-head"><div><h1>{t('geofences.title')}</h1><p>{t('geofences.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel">
        <h2>{t('geofences.newGeofence')}</h2>
        <form onSubmit={submit}>
          <div className="form-row">
            <label>{t('geofences.name')}<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
            <label>{t('geofences.type')}
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                {['zone', 'school', 'police_station', 'hospital', 'event'].map((t) => <option key={t}>{t}</option>)}
              </select>
            </label>
            <label>{t('geofences.region')}<input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} /></label>
            <label>{t('geofences.subCity')}<input value={form.sub_city} onChange={(e) => setForm({ ...form, sub_city: e.target.value })} /></label>
          </div>
          <div className="form-row">
            <label>{t('geofences.centerLat')}<input value={form.center_lat} onChange={(e) => setForm({ ...form, center_lat: e.target.value })} /></label>
            <label>{t('geofences.centerLng')}<input value={form.center_lng} onChange={(e) => setForm({ ...form, center_lng: e.target.value })} /></label>
            <label>{t('geofences.radius')}<input value={form.radius_m} onChange={(e) => setForm({ ...form, radius_m: e.target.value })} /></label>
          </div>
          <button className="btn">{t('geofences.create')}</button>
        </form>
      </div>

      <div className="panel">
        <h2>{t('geofences.zones')}</h2>
        <table>
          <thead><tr><th>{t('geofences.name')}</th><th>{t('geofences.type')}</th><th>{t('geofences.region')}</th><th>Center</th><th>Radius</th><th></th></tr></thead>
          <tbody>
            {rows.map((g) => (
              <tr key={g.id}>
                <td>{g.name}</td><td><span className="badge blue">{g.type}</span></td>
                <td>{g.region || '—'}</td>
                <td>{g.center_lat ? `${g.center_lat.toFixed(4)}, ${g.center_lng.toFixed(4)}` : '—'}</td>
                <td>{g.radius_m ? `${g.radius_m}m` : '—'}</td>
                <td><button className="btn small danger" onClick={() => remove(g.id)}>{t('geofences.delete')}</button></td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('geofences.none')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
