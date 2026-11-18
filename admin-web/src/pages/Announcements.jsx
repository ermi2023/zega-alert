import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { CircleMarker, MapContainer, TileLayer, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { api } from '../api/client';
import { useToast } from '../components/Toast';

function MapClick({ onChange }) {
  useMapEvents({ click: (e) => onChange(e.latlng.lat, e.latlng.lng) });
  return null;
}

export default function Announcements() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState({ title: '', body: '', category: 'news', region: '', sub_city: '', is_published: true, latitude: '', longitude: '' });
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [editing, setEditing] = useState(null);
  const { addToast } = useToast();

  const load = () => api.get('/announcements?include_unpublished=true').then(setRows);
  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      latitude: form.latitude === '' ? null : Number(form.latitude),
      longitude: form.longitude === '' ? null : Number(form.longitude),
    };
    try {
      if (editing) {
        await api.patch(`/announcements/${editing.id}`, payload);
        addToast(t('announcements.updated'), 'ok');
        setEditing(null);
      } else {
        await api.post('/announcements', payload);
        addToast(t('announcements.publishedMsg'), 'ok');
      }
      setForm({ title: '', body: '', category: 'news', region: '', sub_city: '', is_published: true, latitude: '', longitude: '' });
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const remove = async (id) => {
    if (!window.confirm('Delete this announcement?')) return;
    try {
      await api.del(`/announcements/${id}`);
      addToast(t('announcements.deleted'), 'ok');
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const retranslate = async (id) => {
    try {
      await api.post(`/announcements/${id}/retranslate`, {});
      addToast('Translations regenerated.', 'ok');
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const startEdit = (a) => {
    setEditing(a);
    setForm({
      title: a.title, body: a.body, category: a.category, region: a.region || '',
      sub_city: a.sub_city || '', is_published: a.is_published !== false,
      latitude: a.latitude ?? '', longitude: a.longitude ?? '',
    });
  };

  const togglePublish = async (a) => {
    try {
      await api.patch(`/announcements/${a.id}`, { is_published: !a.is_published });
      addToast(a.is_published ? 'Announcement unpublished.' : 'Announcement published.', 'ok');
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  return (
    <div>
      <div className="page-head"><div><h1>{t('announcements.title')}</h1><p>{t('announcements.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel">
        <h2>{editing ? t('announcements.edit') : t('announcements.publish')}</h2>
        <form onSubmit={submit}>
          <div className="form-row">
            <label>{t('announcements.titleField')}<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required /></label>
            <label>{t('announcements.category')}
              <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                {['news', 'warning', 'legal', 'event', 'road_closure', 'missing_item', 'wanted', 'missing'].map((c) => <option key={c} value={c}>{c.replace('_', ' ')}</option>)}
              </select>
            </label>
            <label>{t('announcements.region')}<input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} /></label>
            <label>{t('announcements.subCity')}<input value={form.sub_city} onChange={(e) => setForm({ ...form, sub_city: e.target.value })} /></label>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 20 }}>
              <input type="checkbox" checked={form.is_published} onChange={(e) => setForm({ ...form, is_published: e.target.checked })} />
              Publish immediately
            </label>
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)' }}>{t('announcements.body')}
            <textarea rows={3} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} required />
          </label>
          {form.category === 'road_closure' && (
            <div style={{ marginTop: 12 }}>
              <div style={{ display: 'flex', gap: 8, alignItems: 'end', marginBottom: 8 }}>
                <label style={{ flex: 1 }}>Latitude
                  <input value={form.latitude} onChange={(e) => setForm({ ...form, latitude: e.target.value })} placeholder="9.030000" />
                </label>
                <label style={{ flex: 1 }}>Longitude
                  <input value={form.longitude} onChange={(e) => setForm({ ...form, longitude: e.target.value })} placeholder="38.740000" />
                </label>
                <button type="button" className="btn small ghost" onClick={() => setForm({ ...form, latitude: '', longitude: '' })}>Clear</button>
              </div>
              <div style={{ height: 240, borderRadius: 10, overflow: 'hidden' }}>
                <MapContainer center={[Number(form.latitude) || 9.03, Number(form.longitude) || 38.74]} zoom={13} style={{ width: '100%', height: '100%' }}>
                  <TileLayer attribution='&copy; OpenStreetMap' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
                  <MapClick onChange={(lat, lng) => setForm((f) => ({ ...f, latitude: lat.toFixed(6), longitude: lng.toFixed(6) }))} />
                  {form.latitude !== '' && form.longitude !== '' && (
                    <CircleMarker center={[Number(form.latitude), Number(form.longitude)]} radius={9} pathOptions={{ color: '#dc2626', fillColor: '#ef4444', fillOpacity: 1 }} />
                  )}
                </MapContainer>
              </div>
              <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 4 }}>Click the map to mark the closed road / affected area.</div>
            </div>
          )}
          <div className="form-actions" style={{ marginTop: 12 }}>
            <button className="btn">{editing ? t('announcements.update') : t('announcements.publishBtn')}</button>
            {editing && <button type="button" className="btn ghost" onClick={() => { setEditing(null); setForm({ title: '', body: '', category: 'news', region: '', sub_city: '', is_published: true, latitude: '', longitude: '' }); }}>{t('announcements.cancel')}</button>}
          </div>
        </form>
      </div>

      <div className="panel">
        <h2>{t('announcements.published')}</h2>
        <table>
          <thead><tr><th>{t('announcements.date')}</th><th>{t('announcements.titleField')}</th><th>{t('announcements.category')}</th><th>Region</th><th>Status</th><th>{t('announcements.actions')}</th></tr></thead>
          <tbody>
            {rows.map((a) => (
              <tr key={a.id}>
                <td>{a.published_at ? new Date(a.published_at).toLocaleDateString() : '—'}</td>
                <td>{a.title}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{a.body}</div>
                  {a.translations?.length > 0 && (
                    <div style={{ display: 'flex', gap: 4, marginTop: 4, flexWrap: 'wrap' }}>
                      {a.translations.map((tr) => (
                        <span key={tr.id} className="badge gray" title={tr.title}>
                          {tr.language}{tr.source === 'placeholder' ? '?' : ''}
                        </span>
                      ))}
                    </div>
                  )}
                </td>
                <td>
                  <span className="badge blue">{a.category}</span>
                  {a.latitude != null && a.longitude != null && <span className="badge green" style={{ marginLeft: 4 }}>Mapped</span>}
                </td>
                <td>{a.region || 'National'}</td>
                <td><span className={`badge ${a.is_published ? 'green' : 'gray'}`}>{a.is_published ? 'Published' : 'Draft'}</span></td>
                <td>
                  <button className="btn small" onClick={() => togglePublish(a)}>{a.is_published ? 'Unpublish' : 'Publish'}</button>
                  <button className="btn small ghost" style={{ marginLeft: 4 }} onClick={() => retranslate(a.id)}>Re-translate</button>
                  <button className="btn small ghost" style={{ marginLeft: 4 }} onClick={() => startEdit(a)}>{t('announcements.editBtn')}</button>
                  <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => remove(a.id)}>{t('announcements.delete')}</button>
                </td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('announcements.none')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
