import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

const MODES = ['voice', 'video', 'chat'];
const STATUS_COLOR = { pending: 'amber', accepted: 'green', declined: 'red', completed: 'gray' };

export default function Callbacks() {
  const { t } = useTranslation();
  const [items, setItems] = useState([]);
  const [citizens, setCitizens] = useState([]);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [form, setForm] = useState({
    report_id: '', citizen_id: '', mode: 'voice', requested_slot: '', notes: '',
  });

  const load = () => {
    api.get('/callbacks/officer').then(setItems).catch((e) => setMsg({ type: 'err', text: e.message }));
    api.get('/admin/users?role=citizen&limit=200')
      .then((rows) => setCitizens(rows))
      .catch(() => setCitizens([]));
  };
  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    try {
      await api.post('/callbacks', {
        report_id: form.report_id.trim(),
        citizen_id: form.citizen_id,
        mode: form.mode,
        requested_slot: form.requested_slot ? new Date(form.requested_slot).toISOString() : null,
        notes: form.notes.trim() || null,
      });
      setMsg({ type: 'ok', text: t('callbacks.requested') });
      setForm({ ...form, report_id: '', notes: '' });
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const markDone = async (id) => {
    try { await api.patch(`/callbacks/${id}`, { status: 'completed' }); load(); }
    catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const fmt = (iso) => {
    if (!iso) return '—';
    const d = new Date(iso);
    return d.toLocaleString();
  };

  return (
    <div>
      <div className="page-head"><div><h1>{t('callbacks.title')}</h1><p>{t('callbacks.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel">
        <h2>{t('callbacks.requestCallback')}</h2>
        <form onSubmit={submit}>
          <div className="form-row">
            <label>{t('callbacks.reportId')}
              <input value={form.report_id} onChange={(e) => setForm({ ...form, report_id: e.target.value })} placeholder={t('callbacks.reportIdHint')} required />
            </label>
            <label>{t('callbacks.citizen')}
              <select value={form.citizen_id} onChange={(e) => setForm({ ...form, citizen_id: e.target.value })} required>
                <option value="">{t('callbacks.selectCitizen')}</option>
                {citizens.map((c) => (
                  <option key={c.id} value={c.id}>{c.full_name} ({c.phone})</option>
                ))}
              </select>
            </label>
            <label>{t('callbacks.mode')}
              <select value={form.mode} onChange={(e) => setForm({ ...form, mode: e.target.value })}>
                {MODES.map((m) => <option key={m} value={m}>{m}</option>)}
              </select>
            </label>
            <label>{t('callbacks.scheduledTime')}
              <input type="datetime-local" value={form.requested_slot} onChange={(e) => setForm({ ...form, requested_slot: e.target.value })} />
            </label>
          </div>
          <label>{t('callbacks.notes')}
            <textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} rows="2" />
          </label>
          <button className="btn primary" type="submit">{t('callbacks.requestBtn')}</button>
        </form>
      </div>

      <div className="panel">
        <h2>{t('callbacks.myCallbacks')}</h2>
        <table>
          <thead>
            <tr><th>{t('callbacks.report')}</th><th>Citizen</th><th>{t('callbacks.mode')}</th><th>{t('callbacks.slot')}</th><th>{t('callbacks.status')}</th><th></th></tr>
          </thead>
          <tbody>
            {items.length === 0 && <tr><td colSpan="6" style={{ textAlign: 'center', color: '#888' }}>{t('callbacks.noCallbacks')}</td></tr>}
            {items.map((c) => (
              <tr key={c.id}>
                <td>{c.report_title || c.report_id?.slice(0, 8) || '—'}</td>
                <td>{c.citizen_name || '—'} <small>({c.citizen_phone || '—'})</small></td>
                <td>{c.mode}</td>
                <td>{fmt(c.requested_slot)}</td>
                <td><span className={`badge ${STATUS_COLOR[c.status] || 'gray'}`}>{c.status}</span></td>
                <td>
                  {c.status === 'accepted' && (
                    <button className="btn ghost" onClick={() => markDone(c.id)}>{t('callbacks.markComplete')}</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
