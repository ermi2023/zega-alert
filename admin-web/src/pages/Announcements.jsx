import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api, API_BASE, assetUrl } from '../api/client';
import { useToast } from '../components/Toast';

export default function Announcements() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState({ title: '', body: '', category: 'news', region: '', sub_city: '', image_url: '' });
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [editing, setEditing] = useState(null);
  const [uploading, setUploading] = useState(false);
  const { addToast } = useToast();

  const load = () => api.get('/announcements').then(setRows);
  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    try {
      if (editing) {
        await api.patch(`/announcements/${editing.id}`, form);
        addToast(t('announcements.updated'), 'ok');
        setEditing(null);
      } else {
        await api.post('/announcements', form);
        addToast(t('announcements.publishedMsg'), 'ok');
      }
      setForm({ title: '', body: '', category: 'news', region: '', sub_city: '', image_url: '' });
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
    setForm({ title: a.title, body: a.body, category: a.category, region: a.region || '', sub_city: a.sub_city || '', image_url: a.image_url || '' });
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
          </div>
          <div className="form-row" style={{ marginTop: 8 }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', fontWeight: 600, marginBottom: 4, fontSize: 13 }}>Cover / Header Photo</label>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <input
                  type="file"
                  accept="image/*"
                  disabled={uploading}
                  style={{ fontSize: 12, flex: 1 }}
                  onChange={async (e) => {
                    const file = e.target.files?.[0];
                    if (!file) return;
                    setUploading(true);
                    try {
                      const token = localStorage.getItem('zega_admin_token');
                      const baseUrl = API_BASE || (window.location.hostname === 'localhost' ? 'http://localhost:5000' : '');
                      const fd = new FormData();
                      fd.append('file', file);
                      const res = await fetch(`${baseUrl}/api/upload/single`, {
                        method: 'POST',
                        headers: token ? { Authorization: `Bearer ${token}` } : {},
                        body: fd,
                      });
                      const data = await res.json();
                      const url = data?.data?.url;
                      if (url) setForm(f => ({ ...f, image_url: assetUrl(url) }));
                    } catch (err) { setMsg({ type: 'err', text: 'Upload failed: ' + err.message }); }
                    finally { setUploading(false); }
                  }}
                />
                {uploading && <span style={{ fontSize: 12, color: 'var(--muted)' }}>Uploading...</span>}
                {form.image_url && (
                  <div style={{ position: 'relative', display: 'inline-block' }}>
                    <img
                      src={assetUrl(form.image_url)}
                      alt="Preview"
                      style={{ width: 48, height: 48, objectFit: 'cover', borderRadius: 6, border: '1px solid var(--line)' }}
                    />
                    <button
                      type="button"
                      onClick={() => setForm(f => ({ ...f, image_url: '' }))}
                      style={{
                        position: 'absolute', top: -4, right: -4, background: '#ef4444', color: '#fff',
                        border: 'none', borderRadius: '50%', width: 18, height: 18, fontSize: 11,
                        cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center'
                      }}
                      title="Remove image"
                    >
                      ×
                    </button>
                  </div>
                )}
              </div>
              <input
                type="text"
                value={form.image_url || ''}
                onChange={e => setForm(f => ({ ...f, image_url: e.target.value }))}
                placeholder="Or paste image URL"
                style={{ marginTop: 6, width: '100%', fontSize: 12 }}
              />
            </div>
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)', marginTop: 8 }}>{t('announcements.body')}
            <textarea rows={3} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} required />
          </label>
          <div className="form-actions" style={{ marginTop: 12 }}>
            <button className="btn">{editing ? t('announcements.update') : t('announcements.publishBtn')}</button>
            {editing && <button type="button" className="btn ghost" onClick={() => { setEditing(null); setForm({ title: '', body: '', category: 'news', region: '', sub_city: '', image_url: '' }); }}>{t('announcements.cancel')}</button>}
          </div>
        </form>
      </div>

      <div className="panel">
        <h2>{t('announcements.published')}</h2>
        <table>
          <thead><tr><th>{t('announcements.date')}</th><th>{t('announcements.titleField')}</th><th>{t('announcements.category')}</th><th>Region</th><th>{t('announcements.actions')}</th></tr></thead>
          <tbody>
            {rows.map((a) => (
              <tr key={a.id}>
                <td>{new Date(a.published_at).toLocaleDateString()}</td>
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
                <td><span className="badge blue">{a.category}</span></td>
                <td>{a.region || 'National'}</td>
                <td>
                  <button className="btn small" onClick={() => retranslate(a.id)}>Re-translate</button>
                  <button className="btn small ghost" style={{ marginLeft: 4 }} onClick={() => startEdit(a)}>{t('announcements.editBtn')}</button>
                  <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => remove(a.id)}>{t('announcements.delete')}</button>
                </td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={5} style={{ color: 'var(--muted)' }}>{t('announcements.none')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
