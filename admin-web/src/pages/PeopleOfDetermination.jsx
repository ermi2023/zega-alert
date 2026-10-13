import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import { useToast } from '../components/Toast';
import { io } from 'socket.io-client';

const statusBadge = (s) => ({ requested: 'amber', acknowledged: 'blue', completed: 'green', cancelled: 'gray', submitted: 'amber' }[s] || 'gray');

export default function PeopleOfDetermination() {
  const { t } = useTranslation();
  const [calls, setCalls] = useState([]);
  const [signs, setSigns] = useState([]);
  const { addToast } = useToast();

  const load = () => {
    api.get('/pod/direct-call').then(setCalls).catch(() => {});
    api.get('/pod/sign-language').then(setSigns).catch(() => {});
  };

  useEffect(() => {
    load();
    const socket = io(import.meta.env.VITE_API_URL || undefined, {
      auth: { token: localStorage.getItem('zega_admin_token') },
    });
    socket.on('pod:direct_call', load);
    socket.on('pod:sign_language', load);
    return () => socket.close();
  }, []);

  const update = async (id, status) => {
    try {
      await api.patch(`/pod/direct-call/${id}`, { status });
      addToast(`Request ${status}.`, 'ok');
      load();
    } catch (ex) { addToast(ex.message, 'err'); }
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('pod.title', 'People of Determination')}</h1>
          <p>{t('pod.subtitle', 'Accessibility support: direct police calls & sign language video messages')}</p>
        </div>
        <button className="btn ghost" onClick={load}>{t('sos.refresh')}</button>
      </div>

      <div className="panel">
        <h2>📞 {t('pod.directCalls', 'Direct call requests')}</h2>
        <table>
          <thead><tr><th>{t('sos.time')}</th><th>Citizen</th><th>Phone</th><th>Nearest station</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {calls.map((c) => (
              <tr key={c.id}>
                <td>{new Date(c.created_at).toLocaleString()}</td>
                <td>{c.citizen_name || '—'}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{c.region || '—'}</div></td>
                <td>{c.citizen_phone || '—'}</td>
                <td>{c.station_name || '—'}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{c.station_phone || ''}</div></td>
                <td><span className={`badge ${statusBadge(c.status)}`}>{c.status}</span></td>
                <td>
                  {c.status === 'requested' && <>
                    <button className="btn small" onClick={() => update(c.id, 'acknowledged')}>Acknowledge</button>
                    <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => update(c.id, 'cancelled')}>Cancel</button>
                  </>}
                  {['requested', 'acknowledged'].includes(c.status) &&
                    <button className="btn small" style={{ marginLeft: 4 }} onClick={() => update(c.id, 'completed')}>Complete</button>}
                </td>
              </tr>
            ))}
            {calls.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('pod.noCalls', 'No direct call requests.')}</td></tr>}
          </tbody>
        </table>
      </div>

      <div className="panel">
        <h2>🤟 {t('pod.signLanguage', 'Sign language video messages')}</h2>
        <table>
          <thead><tr><th>{t('sos.time')}</th><th>Citizen</th><th>Note</th><th>Video</th><th>Status</th></tr></thead>
          <tbody>
            {signs.map((s) => (
              <tr key={s.id}>
                <td>{new Date(s.created_at).toLocaleString()}</td>
                <td>{s.citizen_name || '—'}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{s.region || '—'}</div></td>
                <td>{s.note || '—'}</td>
                <td><a className="btn small" href={s.video_url} target="_blank" rel="noreferrer">Open video</a></td>
                <td><span className={`badge ${statusBadge(s.status)}`}>{s.status}</span></td>
              </tr>
            ))}
            {signs.length === 0 && <tr><td colSpan={5} style={{ color: 'var(--muted)' }}>{t('pod.noSigns', 'No sign language messages.')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
