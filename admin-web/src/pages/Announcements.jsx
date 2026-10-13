import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import { useToast } from '../components/Toast';

export default function Announcements() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState({ title: '', body: '', category: 'news', region: '', sub_city: '' });
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [editing, setEditing] = useState(null);
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
      setForm({ title: '', body: '', category: 'news', region: '', sub_city: '' });
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
    setForm({ title: a.title, body: a.body, category: a.category, region: a.region || '', sub_city: a.sub_city || '' });
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
          <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)' }}>{t('announcements.body')}
            <textarea rows={3} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} required />
          </label>
          <div className="form-actions" style={{ marginTop: 12 }}>
            <button className="btn">{editing ? t('announcements.update') : t('announcements.publishBtn')}</button>
            {editing && <button type="button" className="btn ghost" onClick={() => { setEditing(null); setForm({ title: '', body: '', category: 'news', region: '', sub_city: '' }); }}>{t('announcements.cancel')}</button>}
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
