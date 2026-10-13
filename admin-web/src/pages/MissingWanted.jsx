import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

const personBadge = (v) => ({ missing: 'amber', found: 'green', wanted: 'red', captured: 'green' }[v] || 'gray');

const emptyForm = (kind) => ({
  name: '', age: '', gender: '', photo_url: '', description: '', last_seen_address: '',
  crime_description: '', danger_level: 'low', contact_phone: '',
  kind,
});

export default function MissingWanted() {
  const { t } = useTranslation();
  const [missing, setMissing] = useState([]);
  const [pending, setPending] = useState([]);
  const [wanted, setWanted] = useState([]);
  const [sightings, setSightings] = useState([]);
  const [form, setForm] = useState(() => emptyForm('missing'));
  const [msg, setMsg] = useState({ type: '', text: '' });

  const load = () => {
    api.get('/persons/missing').then(setMissing);
    api.get('/persons/missing?approval=pending').then(setPending);
    api.get('/persons/wanted').then(setWanted);
    api.get('/persons/sightings').then(setSightings);
  };
  useEffect(() => { load(); }, []);

  const markMissing = async (id, status) => { await api.patch(`/persons/missing/${id}`, { status }); api.get('/persons/missing').then(setMissing); };
  const markWanted = async (id, status) => { await api.patch(`/persons/wanted/${id}`, { status }); api.get('/persons/wanted').then(setWanted); };
  const approveCase = async (id) => { await api.patch(`/persons/missing/${id}/approve`); setMsg({ type: 'ok', text: 'Case approved and published.' }); load(); };
  const rejectCase = async (id) => {
    const reason = window.prompt('Reason for rejection:', 'Insufficient information');
    if (reason === null) return;
    await api.patch(`/persons/missing/${id}/reject`, { reason });
    setMsg({ type: 'ok', text: 'Case rejected.' });
    load();
  };

  const switchForm = (kind) => setForm((f) => (f.kind === kind ? f : emptyForm(kind)));

  const submit = async (e) => {
    e.preventDefault();
    const kind = form.kind;
    const payload = {
      name: form.name.trim(),
      age: form.age ? parseInt(form.age, 10) : null,
      gender: form.gender || null,
      photo_url: form.photo_url.trim() || null,
      description: form.description.trim() || null,
      contact_phone: form.contact_phone.trim() || null,
    };
    if (kind === 'missing') payload.last_seen_address = form.last_seen_address.trim() || null;
    if (kind === 'wanted') { payload.crime_description = form.crime_description.trim() || null; payload.danger_level = form.danger_level; }
    try {
      await api.post(kind === 'missing' ? '/persons/missing' : '/persons/wanted', payload);
      setMsg({ type: 'ok', text: `${kind === 'missing' ? t('persons.missingRegistered') : t('persons.wantedRegistered')}` });
      setForm(emptyForm(kind));
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  return (
    <div>
      <div className="page-head"><div><h1>{t('persons.title')}</h1><p>{t('persons.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel">
        <h2>{t('persons.registerCase')}</h2>
        <div className="tabs">
          <button className={`tab ${form.kind === 'missing' ? 'active' : ''}`} onClick={() => switchForm('missing')}>{t('persons.missingPerson')}</button>
          <button className={`tab ${form.kind === 'wanted' ? 'active' : ''}`} onClick={() => switchForm('wanted')}>{t('persons.wantedPerson')}</button>
        </div>
        <form onSubmit={submit}>
          <div className="form-row">
            <label>{t('persons.fullName')}<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
            <label>{t('persons.age')}<input value={form.age} type="number" min="0" onChange={(e) => setForm({ ...form, age: e.target.value })} /></label>
            <label>{t('persons.gender')}
              <select value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value })}>
                <option value="">{t('persons.unknown')}</option><option>{t('persons.male')}</option><option>{t('persons.female')}</option>
              </select>
            </label>
            <label>{t('persons.contactPhone')}<input value={form.contact_phone} onChange={(e) => setForm({ ...form, contact_phone: e.target.value })} /></label>
          </div>
          <div className="form-row">
            <label>{t('persons.photoUrl')}<input value={form.photo_url} onChange={(e) => setForm({ ...form, photo_url: e.target.value })} /></label>
            {form.kind === 'missing'
              ? <label>{t('persons.lastSeen')}<input value={form.last_seen_address} onChange={(e) => setForm({ ...form, last_seen_address: e.target.value })} /></label>
              : <label>{t('persons.dangerLevel')}
                  <select value={form.danger_level} onChange={(e) => setForm({ ...form, danger_level: e.target.value })}>
                    {['low', 'medium', 'high', 'critical'].map((d) => <option key={d}>{d}</option>)}
                  </select>
                </label>}
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)' }}>
            {form.kind === 'missing' ? t('persons.description') : t('persons.crimeDescription')}
            <textarea rows={3} value={form.kind === 'missing' ? form.description : form.crime_description}
              onChange={(e) => setForm({ ...form, ...(form.kind === 'missing' ? { description: e.target.value } : { crime_description: e.target.value }) })} />
          </label>
          <div className="form-actions" style={{ marginTop: 12 }}><button className="btn">{t('persons.register')}</button></div>
        </form>
      </div>

      {pending.length > 0 && (
        <div className="panel" style={{ borderColor: 'var(--amber, #f59e0b)' }}>
          <h2>Pending approval ({pending.length})</h2>
          <p style={{ color: 'var(--muted)', fontSize: 13 }}>Citizen submissions awaiting Regional Admin authorization before public listing.</p>
          <table>
            <thead><tr><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>{t('persons.lastSeen')}</th><th>{t('persons.contact')}</th><th>{t('persons.action')}</th></tr></thead>
            <tbody>
              {pending.map((m) => (
                <tr key={m.id}>
                  <td>{m.name}</td><td>{m.age ?? '—'}</td>
                  <td>{m.last_seen_address || '—'}<br /><small>{m.last_seen_at ? new Date(m.last_seen_at).toLocaleString() : '—'}</small></td>
                  <td>{m.contact_phone}</td>
                  <td>
                    <button className="btn small" onClick={() => approveCase(m.id)}>Approve</button>
                    <button className="btn small danger" style={{ marginLeft: 6 }} onClick={() => rejectCase(m.id)}>Reject</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="panel">
        <h2>{t('persons.missingPersons')}</h2>
        <table>
          <thead><tr><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>{t('persons.lastSeen')}</th><th>{t('persons.contact')}</th><th>{t('persons.status')}</th><th>Approval</th><th>{t('persons.action')}</th></tr></thead>
          <tbody>
            {missing.map((m) => (
              <tr key={m.id}>
                <td>{m.name}</td><td>{m.age ?? '—'}</td>
                <td>{m.last_seen_address || '—'}<br /><small>{m.last_seen_at ? new Date(m.last_seen_at).toLocaleString() : '—'}</small></td>
                <td>{m.contact_phone}</td>
                <td><span className={`badge ${personBadge(m.status)}`}>{m.status}</span></td>
                <td>
                  {m.is_approved
                    ? <span className="badge green">approved</span>
                    : (m.rejection_reason ? <span className="badge red">rejected</span> : <span className="badge amber">pending</span>)}
                </td>
                <td>{m.status === 'missing' && <button className="btn small" onClick={() => markMissing(m.id, 'found')}>{t('persons.markFound')}</button>}</td>
              </tr>
            ))}
            {missing.length === 0 && <tr><td colSpan={7} style={{ color: 'var(--muted)' }}>{t('persons.none')}</td></tr>}
          </tbody>
        </table>
      </div>

      <div className="panel">
        <h2>{t('persons.wantedPersons')}</h2>
        <table>
          <thead><tr><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>{t('persons.crime')}</th><th>{t('persons.danger')}</th><th>{t('persons.status')}</th><th>{t('persons.action')}</th></tr></thead>
          <tbody>
            {wanted.map((w) => (
              <tr key={w.id}>
                <td>{w.name}</td><td>{w.age ?? '—'}</td>
                <td>{w.crime_description || '—'}</td><td>{w.danger_level}</td>
                <td><span className={`badge ${personBadge(w.status)}`}>{w.status}</span></td>
                <td>{w.status === 'wanted' && <button className="btn small" onClick={() => markWanted(w.id, 'captured')}>{t('persons.markCaptured')}</button>}</td>
              </tr>
            ))}
            {wanted.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('persons.none')}</td></tr>}
          </tbody>
        </table>
      </div>

      <div className="panel">
        <h2>{t('persons.latestSightings')}</h2>
        <table>
          <thead><tr><th>{t('persons.seen')}</th><th>Location</th><th>Description</th></tr></thead>
          <tbody>
            {sightings.map((s) => (
              <tr key={s.id}>
                <td>{new Date(s.seen_at).toLocaleString()}</td>
                <td>{s.address_text || `${s.latitude?.toFixed(4)}, ${s.longitude?.toFixed(4)}`}</td>
                <td>{s.description || '—'}</td>
              </tr>
            ))}
            {sightings.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('persons.noSightings')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
