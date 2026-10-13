import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import { useToast } from '../components/Toast';

const reviewBadge = (s) => ({ published: 'green', under_review: 'amber', draft: 'gray' }[s] || 'gray');

export default function Legal() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState({ title: '', body: '', category: 'rights', language: 'en', review_status: 'published' });
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [editing, setEditing] = useState(null);
  const [historyFor, setHistoryFor] = useState(null);
  const [history, setHistory] = useState([]);
  const { addToast } = useToast();

  const load = () => api.get('/legal?include_all=true').then(setRows);
  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    try {
      if (editing) {
        await api.patch(`/legal/${editing.id}`, form);
        addToast(t('legal.updated'), 'ok');
        setEditing(null);
      } else {
        await api.post('/legal', form);
        addToast(t('legal.added'), 'ok');
      }
      setForm({ title: '', body: '', category: 'rights', language: 'en', review_status: 'published' });
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const remove = async (id) => {
    if (!window.confirm('Delete this legal article?')) return;
    try {
      await api.del(`/legal/${id}`);
      addToast(t('legal.deleted'), 'ok');
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const review = async (id, review_status) => {
    try {
      await api.patch(`/legal/${id}/review`, { review_status });
      addToast(`Marked as ${review_status}`, 'ok');
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const showHistory = async (l) => {
    setHistoryFor(l);
    try { setHistory(await api.get(`/legal/${l.id}/history`)); } catch { setHistory([]); }
  };

  const startEdit = (l) => {
    setEditing(l);
    setForm({ title: l.title, body: l.body, category: l.category || 'rights', language: l.language || 'en', review_status: l.review_status || 'published' });
  };

  return (
    <div>
      <div className="page-head"><div><h1>{t('legal.title')}</h1><p>{t('legal.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel">
        <h2>{editing ? t('legal.editArticle') : t('legal.addArticle')}</h2>
        <form onSubmit={submit}>
          <div className="form-row">
            <label>{t('legal.titleField')}<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required /></label>
            <label>{t('legal.category')}<input value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} /></label>
            <label>{t('legal.language')}<input value={form.language} onChange={(e) => setForm({ ...form, language: e.target.value })} /></label>
            <label>Review status
              <select value={form.review_status} onChange={(e) => setForm({ ...form, review_status: e.target.value })}>
                {['published', 'under_review', 'draft'].map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </label>
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)' }}>{t('legal.body')}
            <textarea rows={3} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} required />
          </label>
          <div className="form-actions" style={{ marginTop: 12 }}>
            <button className="btn">{editing ? t('legal.update') : t('legal.add')}</button>
            {editing && <button type="button" className="btn ghost" onClick={() => { setEditing(null); setForm({ title: '', body: '', category: 'rights', language: 'en', review_status: 'published' }); }}>{t('legal.cancel')}</button>}
          </div>
        </form>
      </div>

      <div className="panel">
        <h2>{t('legal.library')}</h2>
        <table>
          <thead><tr><th>{t('legal.titleField')}</th><th>{t('legal.category')}</th><th>{t('legal.language')}</th><th>Review</th><th>{t('legal.actions')}</th></tr></thead>
          <tbody>
            {rows.map((l) => (
              <tr key={l.id}>
                <td>{l.title}<div style={{ color: 'var(--muted)', fontSize: 12, maxWidth: 400, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{l.body}</div></td>
                <td><span className="badge blue">{l.category}</span></td>
                <td>{l.language}</td>
                <td><span className={`badge ${reviewBadge(l.review_status)}`}>{(l.review_status || 'published').replace('_', ' ')}</span></td>
                <td>
                  {l.review_status !== 'under_review'
                    ? <button className="btn small" onClick={() => review(l.id, 'under_review')}>Under Review</button>
                    : <button className="btn small" onClick={() => review(l.id, 'published')}>Publish</button>}
                  <button className="btn small ghost" style={{ marginLeft: 4 }} onClick={() => showHistory(l)}>History</button>
                  <button className="btn small ghost" style={{ marginLeft: 4 }} onClick={() => startEdit(l)}>{t('legal.editBtn')}</button>
                  <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => remove(l.id)}>{t('legal.delete')}</button>
                </td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={5} style={{ color: 'var(--muted)' }}>{t('legal.empty')}</td></tr>}
          </tbody>
        </table>
      </div>

      {historyFor && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 60, display: 'grid', placeItems: 'center' }}
          onClick={() => setHistoryFor(null)}>
          <div className="panel" style={{ maxWidth: 560, width: '90%', maxHeight: '80vh', overflow: 'auto' }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h2 style={{ marginTop: 0 }}>Review history — {historyFor.title}</h2>
              <button className="btn ghost" onClick={() => setHistoryFor(null)}>{t('reports.close')}</button>
            </div>
            {history.length === 0 && <p style={{ color: 'var(--muted)' }}>No review history.</p>}
            {history.map((h) => (
              <div key={h.id} style={{ padding: '6px 0', borderBottom: '1px solid rgba(255,255,255,.06)', fontSize: 13 }}>
                <span className="badge blue">{h.action}</span>
                <span style={{ marginLeft: 8 }}>{h.from_status || '—'} → <b>{h.to_status || '—'}</b></span>
                <div style={{ color: 'var(--muted)', marginTop: 2 }}>{new Date(h.created_at).toLocaleString()} · {h.changed_by_name || 'system'}{h.note ? ` · ${h.note}` : ''}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
