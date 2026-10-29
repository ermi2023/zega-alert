import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import { io } from 'socket.io-client';
import LiveMap from '../components/LiveMap';

const badge = (v) => ({ triggered: 'red', acknowledged: 'amber', dispatched: 'blue', resolved: 'green', cancelled: 'gray', pending: 'amber', under_review: 'blue', verified: 'green', rejected: 'red', closed: 'gray' }[v] || 'gray');

const unitStatusStyle = (status) => ({
  completed: { background: '#d4edda', color: '#155724' },
  on_scene: { background: '#cce5ff', color: '#004085' },
  en_route: { background: '#fff3cd', color: '#856404' },
  assigned: { background: '#f8f9fa', color: '#495057' },
}[status] || { background: '#f8f9fa', color: '#495057' });

export default function Sos() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [filter, setFilter] = useState('');
  const [units, setUnits] = useState({});
  const [assignDialog, setAssignDialog] = useState(null);
  const [availableOfficers, setAvailableOfficers] = useState([]);
  const [officers, setOfficers] = useState({});
  const rowsRef = useRef([]);

  const load = () => api.get(`/sos${filter ? `?status=${filter}` : ''}`).then(setRows);
  useEffect(() => { load(); }, [filter]);

  useEffect(() => { rowsRef.current = rows; }, [rows]);

  const loadUnits = async (sosId) => {
    try {
      const data = await api.get(`/dispatch/${sosId}/units`);
      setUnits((prev) => ({ ...prev, [sosId]: data }));
    } catch { /* ignore */ }
  };

  useEffect(() => {
    const socket = io(import.meta.env.VITE_API_URL || undefined, {
      auth: { token: localStorage.getItem('zega_admin_token') },
    });
    socket.on('sos:new', (a) => {
      const alert = a.alert || a;
      setRows((p) => (p.some((x) => x.id === alert.id) ? p : [alert, ...p]));
      socket.emit('join', `sos:${alert.id}`);
    });
    // Citizens stream their GPS every 12s while an SOS is active, so the pin moves.
    socket.on('sos:location', ({ sosId, latitude, longitude }) => {
      setRows((p) => p.map((s) => (s.id === sosId ? { ...s, latitude, longitude } : s)));
    });
    // Patrol units report their position continuously.
    socket.on('officer:position', (p) => {
      setOfficers((prev) => ({ ...prev, [p.userId]: p }));
    });
    socket.on('dispatch:updated', ({ sosId }) => loadUnits(sosId));
    socket.on('connect', () => {
      // Join each active SOS room so dispatch:updated events (emitted to
      // `sos:<id>`) are received instead of only to the staff broadcast.
      rowsRef.current
        .filter((s) => ['triggered', 'acknowledged', 'dispatched'].includes(s.status))
        .forEach((s) => socket.emit('join', `sos:${s.id}`));
    });
    return () => socket.close();
  }, []);

  const rowIds = rows.map((s) => s.id).join(',');
  useEffect(() => {
    rowIds.split(',').filter(Boolean).forEach((id) => loadUnits(id));
  }, [rowIds]);

  useEffect(() => {
    api.get('/position/officers').then((list) => {
      const map = {};
      list.forEach((p) => { map[p.userId] = p; });
      setOfficers(map);
    }).catch(() => {});
  }, []);

  const openAssign = async (sosId) => {
    try {
      const officers = await api.get('/auth/staff?q=');
      setAvailableOfficers(officers.filter((o) => o.role === 'police' || o.role === 'dispatcher'));
    } catch { setAvailableOfficers([]); }
    setAssignDialog(sosId);
  };

  const assignUnits = async (sosId, officerIds) => {
    await api.post(`/dispatch/${sosId}/assign`, { officer_ids: officerIds });
    loadUnits(sosId);
    setAssignDialog(null);
  };

  const removeUnit = async (sosId, assignmentId) => {
    await api.del(`/dispatch/${sosId}/${assignmentId}`);
    loadUnits(sosId);
  };

  const updateUnitStatus = async (sosId, assignmentId, status) => {
    await api.patch(`/dispatch/${sosId}/${assignmentId}/status`, { status });
    loadUnits(sosId);
  };

  const setStatus = async (id, status) => {
    await api.patch(`/sos/${id}/status`, { status });
    load();
  };

  const activeRows = rows.filter((s) => s.latitude && s.longitude && ['triggered', 'acknowledged', 'dispatched'].includes(s.status));
  const officerPts = Object.values(officers).filter((p) => p.latitude && p.longitude);

  return (
    <div>
      <div className="page-head">
        <div><h1>{t('sos.title')}</h1><p>{t('sos.subtitle')}</p></div>
        <div className="filters">
          <select value={filter} onChange={(e) => setFilter(e.target.value)}>
            <option value="">{t('sos.allStatuses')}</option>
            {['triggered', 'acknowledged', 'dispatched', 'resolved', 'cancelled'].map((s) => <option key={s}>{s}</option>)}
          </select>
          <button className="btn ghost" onClick={load}>{t('sos.refresh')}</button>
        </div>
      </div>

      <div className="panel" style={{ marginBottom: 16, padding: 12 }}>
        <div className="section-head" style={{ marginBottom: 10 }}>
          <h2>Live SOS Tracking<small>Citizens &amp; responding units</small></h2>
          <span className="pill"><span className="dot red pulse" /> {activeRows.length} Active</span>
        </div>
        <LiveMap alerts={activeRows} officers={officerPts} height={360} />
      </div>

      <div className="panel">
        <table>
          <thead><tr><th>{t('sos.time')}</th><th>{t('sos.user')}</th><th>{t('reports.location')}</th><th>{t('sos.region')}</th><th>{t('sos.status')}</th><th>{t('sos.actions')}</th></tr></thead>
          <tbody>
            {rows.map((s) => (
              <tr key={s.id}>
                <td>{new Date(s.created_at).toLocaleString()}</td>
                <td>{s.user_name || '—'}<br /><small>{s.user_phone}</small></td>
                <td>{s.address_text || `${s.latitude?.toFixed(4)}, ${s.longitude?.toFixed(4)}`}</td>
                <td>{s.region || '—'}</td>
                <td><span className={`badge ${badge(s.status)}`}>{s.status}</span>
                  {s.geofence && !s.geofence.inside_safety_zone && (
                    <div className="msg err" style={{ margin: '4px 0 0' }}>⚠ Outside safety zones</div>
                  )}
                  {s.geofence?.nearest_police_station && (
                    <div className="msg ok" style={{ margin: '4px 0 0' }}>Police station {Math.round(s.geofence.nearest_police_station.dist)}m away</div>
                  )}
                </td>
                <td>
                  {s.status === 'triggered' && <button className="btn small" onClick={() => setStatus(s.id, 'acknowledged')}>{t('sos.acknowledge')}</button>}
                  {s.status === 'acknowledged' && <button className="btn small" onClick={() => setStatus(s.id, 'dispatched')}>{t('sos.dispatch')}</button>}
                  {['triggered', 'acknowledged', 'dispatched'].includes(s.status) && (
                    <>
                      <button className="btn small" style={{ marginLeft: 6 }} onClick={() => setStatus(s.id, 'resolved')}>{t('sos.resolve')}</button>
                      <button className="btn small danger" style={{ marginLeft: 6 }} onClick={() => setStatus(s.id, 'cancelled')}>{t('sos.cancel')}</button>
                    </>
                  )}
                </td>
              </tr>
            ))}
            {rows.map((s) => (
              <tr key={`${s.id}-units`}>
                <td colSpan={6} style={{ padding: 0 }}>
                  <div style={{ padding: '8px 16px', background: '#f8f9fa', borderTop: '1px solid #eee' }}>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
                      <strong style={{ fontSize: 13 }}>{t('sos.assignedUnits')}</strong>
                      <button className="btn small" onClick={() => openAssign(s.id)}>{t('sos.assignUnit')}</button>
                      <button className="btn small ghost" onClick={() => loadUnits(s.id)}>{t('sos.refresh')}</button>
                    </div>
                    {units[s.id] && units[s.id].length > 0 ? (
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                        {units[s.id].map((u) => (
                          <span key={u.id} style={{
                            display: 'inline-flex', alignItems: 'center', gap: 4,
                            padding: '4px 8px', borderRadius: 6,
                            ...unitStatusStyle(u.status),
                            fontSize: 12, border: '1px solid #ddd',
                          }}>
                            {u.officer_name} ({u.officer_role})
                            <span style={{ fontSize: 10, color: 'var(--muted)' }}>[{u.status}]</span>
                            {u.eta_seconds != null && u.status !== 'completed' && (
                              <span style={{ fontSize: 10, color: '#856404' }}>
                                ETA ~{Math.max(1, Math.round(u.eta_seconds / 60))}m{u.distance_m != null ? ` (${(u.distance_m / 1000).toFixed(1)}km)` : ''}
                              </span>
                            )}
                            {u.status !== 'completed' && (
                              <select
                                value={u.status}
                                onChange={(e) => updateUnitStatus(s.id, u.id, e.target.value)}
                                style={{ fontSize: 10, padding: '1px 2px', marginLeft: 2 }}
                              >
                                {['assigned', 'en_route', 'on_scene', 'completed'].map((st) => (
                                  <option key={st} value={st}>{st}</option>
                                ))}
                              </select>
                            )}
                            <button onClick={() => removeUnit(s.id, u.id)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'red', fontSize: 14 }}>&times;</button>
                          </span>
                        ))}
                      </div>
                    ) : (
                      <span style={{ fontSize: 12, color: 'var(--muted)' }}>{t('sos.noUnits')}</span>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('sos.noAlerts')}</td></tr>}
          </tbody>
        </table>
      </div>

      {assignDialog && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: 'white', borderRadius: 12, padding: 24, maxWidth: 400, width: '90%' }}>
            <h3>{t('sos.assignUnits')}</h3>
            <div style={{ maxHeight: 300, overflow: 'auto' }}>
              {availableOfficers.map((o) => (
                <label key={o.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0', borderBottom: '1px solid #eee' }}>
                  <input type="checkbox" data-officer-id={o.id} />
                  <span>{o.full_name}</span>
                  <span style={{ fontSize: 11, color: 'var(--muted)' }}>{o.role}</span>
                </label>
              ))}
              {availableOfficers.length === 0 && <p style={{ color: 'var(--muted)' }}>{t('sos.noOfficers')}</p>}
            </div>
            <div style={{ marginTop: 16, display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setAssignDialog(null)}>{t('sos.cancel')}</button>
              <button className="btn" onClick={() => {
                const checkboxes = document.querySelectorAll('[data-officer-id]:checked');
                const ids = Array.from(checkboxes).map((cb) => cb.dataset.officerId);
                if (ids.length) assignUnits(assignDialog, ids);
              }}>{t('sos.assignSelected')}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
