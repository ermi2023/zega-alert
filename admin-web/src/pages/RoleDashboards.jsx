import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { io } from 'socket.io-client';
import LiveMap from '../components/LiveMap';

const badge = (v) => ({ pending: 'amber', under_review: 'blue', verified: 'green', resolved: 'green', rejected: 'red', closed: 'gray' }[v] || 'gray');
const badgeSos = (v) => ({ triggered: 'red', acknowledged: 'amber', dispatched: 'blue', resolved: 'green', cancelled: 'gray' }[v] || 'gray');
const LANG_OPTIONS = ['English', 'አማርኛ (Amharic)', 'Afaan Oromoo', 'ትግርኛ (Tigrigna)'];
const countBy = (rows, name) => rows?.find((r) => r.status === name)?.n || 0;

const statCards = (stats, t) => (
  <div className="cards">
    <div className="card green"><div className="num">{stats.users?.total ?? 0}</div><div className="lbl">{t('dashboard.users')} ({stats.users?.citizens ?? 0} {t('dashboard.citizens')})</div></div>
    <div className="card blue"><div className="num">{stats.reports?.reduce((s, r) => s + r.n, 0) ?? 0}</div><div className="lbl">{t('dashboard.crimeReports')}</div></div>
    <div className="card red"><div className="num">{countBy(stats.sos, 'triggered')}</div><div className="lbl">{t('dashboard.activeSos')}</div></div>
    <div className="card amber"><div className="num">{stats.missingPersons?.missing ?? 0}</div><div className="lbl">{t('dashboard.missingPersons')}</div></div>
    <div className="card"><div className="num">{stats.wantedPersons?.wanted ?? 0}</div><div className="lbl">{t('dashboard.wantedPersons')}</div></div>
  </div>
);

/* ---------------------------------------------------------------- */
/* 1. System Admin Dashboard                                          */
/* ---------------------------------------------------------------- */
export function SystemAdminDashboard() {
  const { t } = useTranslation();
  const [stats, setStats] = useState(null);
  const [users, setUsers] = useState([]);
  const [audit, setAudit] = useState([]);
  const [legal, setLegal] = useState([]);
  const [country, setCountry] = useState(null);

  useEffect(() => {
    api.get('/admin/stats').then(setStats).catch(() => {});
    api.get('/admin/users?limit=6').then(setUsers).catch(() => {});
    api.get('/admin/audit?limit=8').then(d => setAudit(d.items || [])).catch(() => {});
    api.get('/legal').then(setLegal).catch(() => {});
    // GeoAPI.info is called directly from the browser (CORS is open). The
    // Render-hosted backend is blocked by GeoAPI's Cloudflare anti-bot layer,
    // so we don't proxy this reference lookup through the API.
    fetch('https://geoapi.info/api/country?code=ET')
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => d && setCountry({
        name: d.name,
        capital: d.capitalCity,
        callingCode: d.callingCode,
        currencyCode: d.currencyCode,
        currencyName: d.currencyName,
        languages: d.languages,
        subdivisionCount: d.subdivisionCount,
        attribution: { source: 'GeoAPI.info', license: 'CC BY-SA 4.0' },
      }))
      .catch(() => {});
  }, []);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('dashboard.systemAdmin')}</h1>
          <p>{t('dashboard.systemAdminSub')}</p>
        </div>
      </div>
      {stats && statCards(stats, t)}

      <div className="cards">
        <div className="card"><h3 style={{ margin: 0 }}>{t('dashboard.staffAccounts')}</h3><p style={{ margin: '6px 0', color: 'var(--muted)' }}>{stats?.users?.staff ?? 0} non-citizen users across 4 roles</p></div>
        <div className="card"><h3 style={{ margin: 0 }}>{t('dashboard.dispatches')}</h3><p style={{ margin: '6px 0', color: 'var(--muted)' }}>{stats?.dispatches?.reduce((s, d) => s + d.n, 0) ?? 0} total assignments</p></div>
        <div className="card"><h3 style={{ margin: 0 }}>{t('dashboard.legalArticles')}</h3><p style={{ margin: '6px 0', color: 'var(--muted)' }}>{legal.length} entries in the rights library</p></div>
        <div className="card">
          <h3 style={{ margin: 0 }}>🌍 {country?.name || 'Ethiopia'} reference</h3>
          {country ? (
            <div style={{ margin: '6px 0', color: 'var(--muted)', fontSize: 13, display: 'grid', gap: 2 }}>
              <span>Capital: <b style={{ color: 'var(--text)' }}>{country.capital || '—'}</b></span>
              <span>Calling code: <b style={{ color: 'var(--text)' }}>+{country.callingCode ?? '—'}</b></span>
              <span>Currency: <b style={{ color: 'var(--text)' }}>{country.currencyName || '—'} ({country.currencyCode || '—'})</b></span>
              <span>Regions: <b style={{ color: 'var(--text)' }}>{country.subdivisionCount ?? '—'}</b></span>
            </div>
          ) : <p style={{ margin: '6px 0', color: 'var(--muted)' }}>Reference unavailable.</p>}
          <small style={{ color: 'var(--muted)', fontSize: 11 }}>Source: {country?.attribution?.source || 'GeoAPI.info'} · {country?.attribution?.license || 'CC BY-SA 4.0'}</small>
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <h2>👤 {t('dashboard.userManagement')}</h2>
          <table>
            <thead><tr><th>Name</th><th>Phone</th><th>Role</th><th>Status</th></tr></thead>
            <tbody>
              {users.slice(0, 5).map((u) => (
                <tr key={u.id}>
                  <td>{u.full_name}</td><td>{u.phone}</td>
                  <td><span className="badge blue">{u.role}</span></td>
                  <td>{u.is_active ? <span className="badge green">{t('users.active')}</span> : <span className="badge red">{t('users.disabled')}</span>}</td>
                </tr>
              ))}
              {users.length === 0 && <tr><td colSpan={4} style={{ color: 'var(--muted)' }}>{t('users.noUsers')}</td></tr>}
            </tbody>
          </table>
          <a className="btn small" style={{ marginTop: 12, display: 'inline-block', textDecoration: 'none' }} href="/users">{t('dashboard.manageUsers')} →</a>
        </div>

        <div className="panel">
          <h2>📡 {t('dashboard.carrierConfig')}</h2>
          <div className="carrier-list">
            <div className="carrier"><b>Ethio Telecom</b><span className="badge green">{t('users.active')}</span></div>
            <div className="carrier"><b>Safaricom Ethiopia</b><span className="badge green">{t('users.active')}</span></div>
            <div className="carrier"><b>Future entrants</b><span className="badge gray">pending</span></div>
          </div>
          <h2 style={{ marginTop: 18 }}>🔐 {t('dashboard.securityPolicy')}</h2>
          <ul className="policy">
            <li>TLS 1.3 encryption for all data in transit</li>
            <li>bcrypt password hashing + AES-256-GCM at rest</li>
            <li>Rate limiting · 100 requests / minute / user</li>
            <li>RBAC with hierarchical role creation</li>
          </ul>
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <h2>🔎 {t('dashboard.auditLog')}</h2>
          <table>
            <thead><tr><th>Time</th><th>User</th><th>Action</th></tr></thead>
            <tbody>
              {audit.map((a) => (
                <tr key={a.id}>
                  <td>{new Date(a.created_at).toLocaleString()}</td>
                  <td>{a.full_name || 'system'}</td>
                  <td>{a.action}</td>
                </tr>
              ))}
              {audit.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>No activity yet.</td></tr>}
            </tbody>
          </table>
          <a className="btn small" style={{ marginTop: 12, display: 'inline-block', textDecoration: 'none' }} href="/audit">{t('dashboard.openAuditLog')} →</a>
        </div>

        <div className="panel">
          <h2>⚖ {t('dashboard.legalContent')}</h2>
          <table>
            <thead><tr><th>Title</th><th>Category</th><th>Language</th></tr></thead>
            <tbody>
              {legal.slice(0, 5).map((l) => (
                <tr key={l.id}><td>{l.title}</td><td><span className="badge blue">{l.category}</span></td><td>{l.language}</td></tr>
              ))}
              {legal.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('legal.empty')}</td></tr>}
            </tbody>
          </table>
          <a className="btn small" style={{ marginTop: 12, display: 'inline-block', textDecoration: 'none' }} href="/legal">{t('dashboard.manageLegal')} →</a>
        </div>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------- */
/* 2. Regional Admin Dashboard                                       */
/* ---------------------------------------------------------------- */
export function RegionalAdminDashboard() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [form, setForm] = useState({ title: '', body: '', category: 'news', region: user?.region || '', sub_city: '' });
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [reports, setReports] = useState([]);
  const [officers, setOfficers] = useState([]);
  const [regionStats, setRegionStats] = useState([]);
  const [preview, setPreview] = useState(null);

  useEffect(() => {
    api.get('/admin/stats').then(setStats).catch(() => {});
    api.get('/reports?status=pending').then((d) => setReports(d.items)).catch(() => {});
    api.get('/reports?status=under_review').then((d) => setReports((p) => [...p, ...d.items])).catch(() => {});
    api.get('/admin/users?role=police').then(setOfficers).catch(() => {});
    api.get('/reports').then((d) => {
      const byRegion = {};
      d.items.forEach((r) => { const k = r.region || 'Unknown'; byRegion[k] = (byRegion[k] || 0) + 1; });
      setRegionStats(Object.entries(byRegion).map(([region, n]) => ({ region, n })));
    }).catch(() => {});
  }, []);

  const previewTranslation = async (e) => {
    e.preventDefault();
    if (!form.title.trim()) return;
    setPreview({ ...form });
  };

  const publish = async () => {
    try {
      await api.post('/announcements', form);
      setMsg({ type: 'ok', text: 'Announcement published with auto-translation to all languages.' });
      setForm({ title: '', body: '', category: 'news', region: user?.region || '', sub_city: '' });
      setPreview(null);
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const assign = async (id, officerId) => {
    if (!officerId) return;
    await api.patch(`/reports/${id}/status`, { status: 'under_review', assigned_to: officerId });
    setReports((p) => p.filter((r) => r.id !== id));
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('dashboard.regionalAdmin')}</h1>
          <p>{t('dashboard.regionalAdminSub')}</p>
        </div>
      </div>
      {stats && statCards(stats, t)}

      <div className="panel">
        <h2>📢 {t('dashboard.announcementMgmt')}</h2>
        {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}
        <form onSubmit={previewTranslation}>
          <div className="form-row">
            <label>{t('reports.reportTitle')}<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required /></label>
            <label>{t('reports.category')}
              <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                {['news', 'warning', 'legal', 'event'].map((c) => <option key={c}>{c}</option>)}
              </select>
            </label>
            <label>{t('reports.location')} (blank = national)<input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} /></label>
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)' }}>{t('announcements.body')}
            <textarea rows={3} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} required />
          </label>
          <div className="form-actions" style={{ marginTop: 12 }}>
            <button className="btn">{t('dashboard.previewTranslations')}</button>
          </div>
        </form>

        {preview && (
          <div className="translation-preview">
            <h3>{t('dashboard.translationPreview')}</h3>
            <div className="lang-grid">
              {LANG_OPTIONS.map((lang, i) => (
                <div key={lang} className="lang-card">
                  <b>{lang}</b>
                  <p>{i === 0 ? preview.title : `${preview.title} (${['Amharic', 'Oromifa', 'Tigrigna'][i - 1]})`}</p>
                  <small>{preview.body}</small>
                </div>
              ))}
            </div>
            <div className="form-actions" style={{ marginTop: 12 }}>
              <button className="btn" onClick={publish}>{t('dashboard.publishWithTranslations')}</button>
              <button className="btn ghost" onClick={() => setPreview(null)}>{t('dashboard.editAgain')}</button>
            </div>
          </div>
        )}
      </div>

      <div className="grid-2">
        <div className="panel">
          <h2>⚑ {t('dashboard.reportAssignment')}</h2>
          <table>
            <thead><tr><th>{t('reports.reportTitle')}</th><th>{t('reports.severity')}</th><th>Assign to</th></tr></thead>
            <tbody>
              {reports.map((r) => (
                <tr key={r.id}>
                  <td>{r.title}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{r.category}</div></td>
                  <td><span className={`badge ${r.severity === 'critical' ? 'red' : r.severity === 'high' ? 'amber' : 'blue'}`}>{r.severity}</span></td>
                  <td>
                    <select defaultValue="" onChange={(e) => e.target.value && assign(r.id, e.target.value)}>
                      <option value="" disabled>{t('dashboard.selectOfficer')}</option>
                      {officers.map((o) => <option key={o.id} value={o.id}>{o.full_name}</option>)}
                    </select>
                  </td>
                </tr>
              ))}
              {reports.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('dashboard.noReportsAwaiting')}</td></tr>}
            </tbody>
          </table>
        </div>

        <div className="panel">
          <h2>🌍 {t('dashboard.crossRegional')}</h2>
          <table>
            <thead><tr><th>{t('reports.location')}</th><th>Reports</th></tr></thead>
            <tbody>
              {regionStats.map((r) => (
                <tr key={r.region}><td>{r.region}</td><td><b>{r.n}</b></td></tr>
              ))}
              {regionStats.length === 0 && <tr><td colSpan={2} style={{ color: 'var(--muted)' }}>{t('dashboard.noData')}</td></tr>}
            </tbody>
          </table>
          <div className="bar-chart">
            {regionStats.map((r) => (
              <div key={r.region} className="bar" style={{ flexGrow: r.n + 1 }} title={`${r.region}: ${r.n}`}><span>{r.region}</span></div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------- */
/* 3. Emergency Dispatcher Dashboard                                 */
/* ---------------------------------------------------------------- */
export function DispatcherDashboard() {
  const { t } = useTranslation();
  const [sos, setSos] = useState([]);
  const [officers, setOfficers] = useState([]);
  const [live, setLive] = useState([]);
  const [officerPositions, setOfficerPositions] = useState({});

  const load = () => {
    api.get('/sos').then(setSos).catch(() => {});
    api.get('/admin/users?role=police').then(setOfficers).catch(() => {});
    api.get('/position/officers').then((list) => {
      const m = {};
      list.forEach((p) => { m[p.userId] = p; });
      setOfficerPositions(m);
    }).catch(() => {});
  };

  useEffect(() => {
    load();
    const socket = io(import.meta.env.VITE_API_URL || undefined, {
      auth: { token: localStorage.getItem('zega_admin_token') },
    });
    socket.on('sos:new', (a) => {
      setSos((p) => [a.alert || a, ...p]);
      setLive((p) => [a.alert || a, ...p].slice(0, 12));
    });
    socket.on('officer:position', (p) => {
      setOfficerPositions((prev) => ({ ...prev, [p.userId]: p }));
    });
    return () => socket.close();
  }, []);

  const open = (s) => sos.find((x) => x.id === s.id) || s;

  const dispatch = async (s, officerId) => {
    if (!officerId) return;
    const target = open(s);
    await api.post(`/sos/${target.id}/assign`, { assigned_to: officerId });
    await api.patch(`/sos/${target.id}/status`, { status: 'dispatched' });
    load();
  };

  const acknowledge = async (s) => {
    await api.patch(`/sos/${open(s).id}/status`, { status: 'acknowledged' });
    load();
  };

  const resolve = async (s) => {
    await api.patch(`/sos/${open(s).id}/status`, { status: 'resolved' });
    load();
  };

  const points = useMemo(() => sos.filter((s) => s.latitude && s.longitude), [sos]);
  const officerPts = useMemo(() => Object.values(officerPositions).filter((p) => p.latitude && p.longitude), [officerPositions]);
  const active = sos.filter((s) => ['triggered', 'acknowledged', 'dispatched'].includes(s.status));
  const available = officers.filter((o) => o.is_active);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('dashboard.dispatcher')}</h1>
          <p>{t('dashboard.dispatcherSub')}</p>
        </div>
      </div>

      {live.length > 0 && (
        <div className="panel">
          <h2>🔴 {t('dashboard.liveSos')}</h2>
          {live.map((a) => (
            <div key={a.id} className="msg err">New SOS from {a.user_name || 'unknown'} — {a.address_text || `${a.latitude}, ${a.longitude}`}</div>
          ))}
        </div>
      )}

      <div className="grid-2">
        <div className="panel">
          <h2>🗺 {t('dashboard.liveMap')} <small style={{ color: 'var(--muted)', fontWeight: 400 }}>· {officerPts.length} officers live</small></h2>
          {(points.length > 0 || officerPts.length > 0) ? (
            <LiveMap alerts={points} officers={officerPts} height={340} />
          ) : (
            <p style={{ color: 'var(--muted)' }}>{t('dashboard.noGps')}</p>
          )}
        </div>

        <div className="panel">
          <h2>👮 {t('dashboard.officerTracker')}</h2>
          <table>
            <thead><tr><th>Officer</th><th>Region</th><th>Status</th></tr></thead>
            <tbody>
              {available.map((o) => (
                <tr key={o.id}>
                  <td>{o.full_name}</td>
                  <td>{o.region || '—'}</td>
                  <td><span className="badge green">{t('dashboard.available')}</span></td>
                </tr>
              ))}
              {available.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('dashboard.noOfficersOnline')}</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <h2>🚨 {t('dashboard.dispatchPanel')}</h2>
          <table>
            <thead><tr><th>Citizen</th><th>Location</th><th>Status</th><th>Dispatch to</th></tr></thead>
            <tbody>
              {active.map((s) => (
                <tr key={s.id}>
                  <td>{s.user_name || '—'}<br /><small>{s.user_phone}</small></td>
                  <td>{s.address_text || `${s.latitude?.toFixed(4)}, ${s.longitude?.toFixed(4)}`}</td>
                  <td><span className={`badge ${badgeSos(s.status)}`}>{s.status}</span>
                    {s.geofence && !s.geofence.inside_safety_zone && (
                      <div className="msg err" style={{ margin: '4px 0 0' }}>⚠ {t('dashboard.outsideZones')}</div>
                    )}
                    {s.geofence?.nearest_police_station && (
                      <div className="msg ok" style={{ margin: '4px 0 0' }}>Police station {Math.round(s.geofence.nearest_police_station.dist)}m away</div>
                    )}
                  </td>
                  <td>
                    <select defaultValue="" onChange={(e) => e.target.value && dispatch(s, e.target.value)}>
                      <option value="" disabled>{t('dashboard.assign')}</option>
                      {available.map((o) => <option key={o.id} value={o.id}>{o.full_name}</option>)}
                    </select>
                  </td>
                </tr>
              ))}
              {active.length === 0 && <tr><td colSpan={4} style={{ color: 'var(--muted)' }}>{t('dashboard.allClear')}</td></tr>}
            </tbody>
          </table>
        </div>

        <div className="panel">
          <h2>📞 {t('dashboard.callbackQueue')}</h2>
          <table>
            <thead><tr><th>Citizen</th><th>Phone</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {sos.filter((s) => ['triggered', 'acknowledged'].includes(s.status)).map((s) => (
                <tr key={s.id}>
                  <td>{s.user_name || '—'}</td>
                  <td>{s.user_phone || '—'}</td>
                  <td><span className={`badge ${badgeSos(s.status)}`}>{s.status}</span></td>
                  <td>
                    {s.status === 'triggered' && <button className="btn small" onClick={() => acknowledge(s)}>{t('dashboard.acknowledge')}</button>}
                    {s.status === 'acknowledged' && <button className="btn small" onClick={() => resolve(s)}>{t('dashboard.markContacted')}</button>}
                  </td>
                </tr>
              ))}
              {sos.filter((s) => ['triggered', 'acknowledged'].includes(s.status)).length === 0 && (
                <tr><td colSpan={4} style={{ color: 'var(--muted)' }}>{t('dashboard.queueEmpty')}</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------- */
/* 4. Regional Police Dashboard                                      */
/* ---------------------------------------------------------------- */
export function PoliceDashboard() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [reports, setReports] = useState([]);
  const [sos, setSos] = useState([]);
  const [announcements, setAnnouncements] = useState([]);

  useEffect(() => {
    api.get('/reports').then((d) => setReports(d.items)).catch(() => {});
    api.get('/sos').then(setSos).catch(() => {});
    api.get('/announcements').then(setAnnouncements).catch(() => {});
  }, []);

  const mine = reports.filter((r) => r.assigned_to === user.id);
  const open = reports.filter((r) => !['resolved', 'rejected', 'closed'].includes(r.status) && !r.assigned_to);

  const setStatus = async (id, status) => {
    await api.patch(`/reports/${id}/status`, { status });
    const d = await api.get('/reports');
    setReports(d.items);
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('dashboard.police')}</h1>
          <p>{t('dashboard.policeSub')}</p>
        </div>
      </div>

      <div className="cards">
        <div className="card blue"><div className="num">{mine.length}</div><div className="lbl">{t('dashboard.assignedToYou')}</div></div>
        <div className="card amber"><div className="num">{open.length}</div><div className="lbl">{t('dashboard.unassigned')}</div></div>
        <div className="card red"><div className="num">{sos.filter((s) => ['triggered', 'acknowledged', 'dispatched'].includes(s.status)).length}</div><div className="lbl">{t('dashboard.activeSosRegion')}</div></div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <h2>📋 {t('dashboard.assignedCases')}</h2>
          <table>
            <thead><tr><th>{t('reports.reportTitle')}</th><th>{t('reports.severity')}</th><th>Status</th><th>Action</th></tr></thead>
            <tbody>
              {mine.map((r) => (
                <tr key={r.id}>
                  <td>{r.title}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{r.region || '—'} · {r.sub_city || '—'}</div></td>
                  <td><span className={`badge ${r.severity === 'critical' ? 'red' : r.severity === 'high' ? 'amber' : 'blue'}`}>{r.severity}</span></td>
                  <td><span className={`badge ${badge(r.status)}`}>{r.status}</span></td>
                  <td>
                    {r.status === 'under_review' && <button className="btn small" onClick={() => setStatus(r.id, 'verified')}>Verify</button>}
                    {r.status === 'verified' && <button className="btn small" onClick={() => setStatus(r.id, 'resolved')}>Resolve</button>}
                  </td>
                </tr>
              ))}
              {mine.length === 0 && <tr><td colSpan={4} style={{ color: 'var(--muted)' }}>{t('dashboard.noCases')}</td></tr>}
            </tbody>
          </table>
        </div>

        <div className="panel">
          <h2>⚑ {t('dashboard.unassignedQueue')}</h2>
          <table>
            <thead><tr><th>{t('reports.reportTitle')}</th><th>{t('reports.category')}</th><th>Priority</th></tr></thead>
            <tbody>
              {open.slice(0, 8).map((r) => (
                <tr key={r.id}>
                  <td>{r.title}</td>
                  <td><span className="badge blue">{r.category}</span></td>
                  <td><span className={`badge ${r.priority_score >= 70 ? 'red' : 'amber'}`}>{r.priority_score ?? '—'}</span></td>
                </tr>
              ))}
              {open.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('dashboard.queueEmpty')}</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      <div className="panel">
        <h2>📢 {t('dashboard.latestAnnouncements')}</h2>
        <table>
          <thead><tr><th>Date</th><th>{t('reports.reportTitle')}</th><th>{t('reports.category')}</th></tr></thead>
          <tbody>
            {announcements.slice(0, 5).map((a) => (
              <tr key={a.id}>
                <td>{new Date(a.published_at).toLocaleDateString()}</td>
                <td>{a.title}</td>
                <td><span className="badge blue">{a.category}</span></td>
              </tr>
            ))}
            {announcements.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('dashboard.none')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
