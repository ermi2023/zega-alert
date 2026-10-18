import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { io } from 'socket.io-client';
import LiveMap from '../components/LiveMap';
import Icon from '../components/Icon';

// Reusable inline SVG bar chart (no external chart lib).
const BarChart = ({ data, color = '#22c55e', height = 120, labelKey = 'label', valueKey = 'value' }) => {
  if (!data || data.length === 0) return <div style={{ color: 'var(--muted)', fontSize: 13, padding: 12 }}>No data</div>;
  const max = Math.max(...data.map((d) => d[valueKey] || 0), 1);
  const barW = Math.max(8, Math.floor(280 / data.length) - 6);
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${data.length * (barW + 6) + 10} ${height}`} style={{ overflow: 'visible' }}>
      {data.map((d, i) => {
        const v = d[valueKey] || 0;
        const h = (v / max) * (height - 24);
        const x = i * (barW + 6) + 4;
        const y = height - h - 18;
        return (
          <g key={i}>
            <rect x={x} y={y} width={barW} height={h} rx={4} fill={color} opacity={0.85} />
            <text x={x + barW / 2} y={height - 4} textAnchor="middle" fontSize={9} fill="var(--muted)">{String(d[labelKey] || '').slice(0, 8)}</text>
            <text x={x + barW / 2} y={y - 3} textAnchor="middle" fontSize={9} fill="var(--text)" fontWeight={600}>{v}</text>
          </g>
        );
      })}
    </svg>
  );
};
const badgeSos = (v) => ({ triggered: 'red', acknowledged: 'amber', dispatched: 'blue', resolved: 'green', cancelled: 'gray' }[v] || 'gray');
const LANG_OPTIONS = ['English', 'አማርኛ (Amharic)', 'Afaan Oromoo', 'ትግርኛ (Tigrigna)'];
const countBy = (rows, name) => rows?.find((r) => r.status === name)?.n || 0;

const statCards = (stats, t) => (
  <div className="cards kpi-grid">
    <div className="card kpi">
      <div className="kpi-top">
        <span className="kpi-icon green"><Icon name="users" size={18} /></span>
        <span className="kpi-label">{t('dashboard.users')}</span>
      </div>
      <div className="kpi-value">{stats.users?.total ?? 0}</div>
      <div className="kpi-meta">{stats.users?.citizens ?? 0} {t('dashboard.citizens')} · {stats.users?.staff ?? 0} staff</div>
    </div>
    <div className="card kpi">
      <div className="kpi-top">
        <span className="kpi-icon blue"><Icon name="reports" size={18} /></span>
        <span className="kpi-label">{t('dashboard.crimeReports')}</span>
      </div>
      <div className="kpi-value">{stats.reports?.reduce((s, r) => s + r.n, 0) ?? 0}</div>
      <div className="kpi-meta">Across all regions</div>
    </div>
    <div className="card kpi">
      <div className="kpi-top">
        <span className="kpi-icon red"><Icon name="sos" size={18} /></span>
        <span className="kpi-label">{t('dashboard.activeSos')}</span>
      </div>
      <div className="kpi-value">{countBy(stats.sos, 'triggered')}</div>
      <div className="kpi-meta">{countBy(stats.sos, 'dispatched')} dispatched · {countBy(stats.sos, 'acknowledged')} ack</div>
    </div>
    <div className="card kpi">
      <div className="kpi-top">
        <span className="kpi-icon amber"><Icon name="persons" size={18} /></span>
        <span className="kpi-label">{t('dashboard.missingPersons')}</span>
      </div>
      <div className="kpi-value">{stats.missingPersons?.missing ?? 0}</div>
      <div className="kpi-meta">Active cases</div>
    </div>
    <div className="card kpi">
      <div className="kpi-top">
        <span className="kpi-icon indigo"><Icon name="persons" size={18} /></span>
        <span className="kpi-label">{t('dashboard.wantedPersons')}</span>
      </div>
      <div className="kpi-value">{stats.wantedPersons?.wanted ?? 0}</div>
      <div className="kpi-meta">Open alerts</div>
    </div>
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

  const [policy, setPolicy] = useState(null);

  useEffect(() => {
    api.get('/admin/stats').then(setStats).catch(() => {});
    api.get('/admin/users?limit=6').then(setUsers).catch(() => {});
    api.get('/admin/audit?limit=8').then(d => setAudit(d.items || [])).catch(() => {});
    api.get('/legal').then(setLegal).catch(() => {});
    api.get('/policy').then(setPolicy).catch(() => {});
    fetch('https://geoapi.info/api/country?code=ET')
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
      <div className="page-head hero">
        <div>
          <h1>{t('dashboard.systemAdmin')}</h1>
          <p>{t('dashboard.systemAdminSub')}</p>
        </div>
        <div className="hero-meta">
          <span className="pill"><Icon name="clock" size={14} /> {new Date().toLocaleDateString()}</span>
          <span className="pill"><Icon name="shield" size={14} /> Live</span>
        </div>
      </div>
      {stats && statCards(stats, t)}

      <div className="cards info-grid">
        <div className="card info">
          <span className="kpi-icon indigo"><Icon name="users" size={18} /></span>
          <div><b>{stats?.users?.staff ?? 0}</b><p>{t('dashboard.staffAccounts')} · 4 roles</p></div>
        </div>
        <div className="card info">
          <span className="kpi-icon blue"><Icon name="chart" size={18} /></span>
          <div><b>{stats?.dispatches?.reduce((s, d) => s + d.n, 0) ?? 0}</b><p>{t('dashboard.dispatches')} · total assignments</p></div>
        </div>
        <div className="card info">
          <span className="kpi-icon green"><Icon name="legal" size={18} /></span>
          <div><b>{legal.length}</b><p>{t('dashboard.legalArticles')} · rights library</p></div>
        </div>
        <div className="card info country">
          <span className="kpi-icon amber"><Icon name="globe" size={18} /></span>
          <div className="country-body">
            <b>{country?.name || 'Ethiopia'}</b>
            {country ? (
              <div className="country-meta">
                <span>Capital <strong>{country.capital || '—'}</strong></span>
                <span>Call <strong>+{country.callingCode ?? '—'}</strong></span>
                <span>Currency <strong>{country.currencyCode || '—'}</strong></span>
                <span>Regions <strong>{country.subdivisionCount ?? '—'}</strong></span>
              </div>
            ) : <p>Reference unavailable.</p>}
            <small>Source: {country?.attribution?.source || 'GeoAPI.info'} · {country?.attribution?.license || 'CC BY-SA 4.0'}</small>
          </div>
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <div className="section-head">
            <h2>{t('dashboard.userManagement')}<small>latest accounts</small></h2>
            <a className="btn small ghost" href="/users">{t('dashboard.manageUsers')} →</a>
          </div>
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
        </div>

        <div className="panel">
          <div className="section-head"><h2>Reports by status<small>distribution</small></h2></div>
          <BarChart data={(stats?.reports || []).map((r) => ({ label: r.status, value: r.n }))} color="#38bdf8" />
          <div className="section-head" style={{ marginTop: 18 }}><h2>Staff by role<small>breakdown</small></h2></div>
          <BarChart data={(() => {
            const byRole = {};
            users.forEach((u) => { if (u.role !== 'citizen') byRole[u.role] = (byRole[u.role] || 0) + 1; });
            return Object.entries(byRole).map(([k, v]) => ({ label: k, value: v }));
          })()} color="#a5b4fc" />
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <div className="section-head">
            <h2>{t('dashboard.auditLog')}<small>recent activity</small></h2>
            <a className="btn small ghost" href="/audit">{t('dashboard.openAuditLog')} →</a>
          </div>
          <table>
            <thead><tr><th>Time</th><th>User</th><th>Action</th></tr></thead>
            <tbody>
              {audit.map((a) => (
                <tr key={a.id}>
                  <td>{new Date(a.created_at).toLocaleString()}</td>
                  <td>{a.full_name || 'system'}</td>
                  <td><span className="badge gray">{a.action}</span></td>
                </tr>
              ))}
              {audit.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>No activity yet.</td></tr>}
            </tbody>
          </table>
        </div>

        <div className="panel">
          <div className="section-head">
            <h2>{t('dashboard.securityPolicy')}<small>from /api/policy</small></h2>
          </div>
          {policy ? (
            <ul className="policy">
              <li>TLS 1.3: <b>{String(policy.tls_enforced)}</b></li>
              <li>bcrypt cost: <b>{policy.bcrypt_cost}</b></li>
              <li>Rate limit: <b>{policy.rate_limit_per_minute}/min</b></li>
              <li>Password min length: <b>{policy.password_min_length}</b></li>
              <li>Session timeout: <b>{policy.session_timeout_minutes} min</b></li>
              <li>MFA required: <b>{String(policy.mfa_required)}</b></li>
              <li>Audit retention: <b>{policy.audit_retention_days} days</b></li>
            </ul>
          ) : <p style={{ color: 'var(--muted)' }}>Policy unavailable.</p>}
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <div className="section-head">
            <h2>{t('dashboard.legalContent')}<small>rights library</small></h2>
            <a className="btn small ghost" href="/legal">{t('dashboard.manageLegal')} →</a>
          </div>
          <table>
            <thead><tr><th>Title</th><th>Category</th><th>Language</th></tr></thead>
            <tbody>
              {legal.slice(0, 5).map((l) => (
                <tr key={l.id}><td>{l.title}</td><td><span className="badge blue">{l.category}</span></td><td>{l.language}</td></tr>
              ))}
              {legal.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('legal.empty')}</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

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
      <div className="page-head hero">
        <div>
          <h1>{t('dashboard.regionalAdmin')}</h1>
          <p>{t('dashboard.regionalAdminSub')}</p>
        </div>
        <div className="hero-meta">
          <span className="pill"><span className="dot amber" /> {reports.length} pending</span>
          <span className="pill"><span className="dot green" /> {officers.length} officers</span>
          <span className="pill"><Icon name="pin" size={14} /> {user?.region || '—'}</span>
        </div>
      </div>
      {stats && statCards(stats, t)}

      <div className="panel">
        <div className="section-head"><h2>{t('dashboard.announcementMgmt')}<small>auto-translated publishing</small></h2></div>
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
              <p style={{ color: 'var(--muted)', fontSize: 13 }}>
                On publish, the backend auto-translates this announcement into Amharic, Oromifa and Tigrigna
                using the configured translation engine (LibreTranslate-compatible). The preview below shows
                the source text; translated variants are generated server-side and stored as separate rows.
              </p>
              <div className="lang-grid">
                {LANG_OPTIONS.map((lang, i) => (
                  <div key={lang} className="lang-card">
                    <b>{lang}</b>
                    <p>{preview.title}</p>
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
          <div className="section-head">
            <h2>{t('dashboard.reportAssignment')}<small>{reports.length} awaiting</small></h2>
            <a className="btn small ghost" href="/reports">All reports →</a>
          </div>
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
          <div className="section-head"><h2>{t('dashboard.crossRegional')}<small>reports by region</small></h2></div>
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
      <div className="page-head hero">
        <div>
          <h1>{t('dashboard.dispatcher')}</h1>
          <p>{t('dashboard.dispatcherSub')}</p>
        </div>
        <div className="hero-meta">
          <span className="pill"><span className={`dot ${active.length ? 'red' : 'green'}`} /> {active.length} active SOS</span>
          <span className="pill"><span className="dot green" /> {officerPts.length} live officers</span>
          <span className="pill"><Icon name="clock" size={14} /> {new Date().toLocaleTimeString()}</span>
        </div>
      </div>

      {live.length > 0 && (
        <div className="panel alert-strip">
          <div className="section-head">
            <h2><span className="dot red pulse" /> {t('dashboard.liveSos')}<small>{live.length} new this session</small></h2>
            <a className="btn small ghost" href="/sos">Open queue →</a>
          </div>
          <div className="alert-list">
            {live.map((a) => (
              <div key={a.id} className="alert-item">
                <b>{a.user_name || 'Unknown'}</b>
                <span>{a.address_text || `${a.latitude}, ${a.longitude}`}</span>
                <span className={`badge ${badgeSos(a.status)}`}>{a.status}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="grid-2">
        <div className="panel">
          <div className="section-head">
            <h2>{t('dashboard.liveMap')}<small>{officerPts.length} officers live</small></h2>
            <span className="pill"><span className="dot blue" /> OSM · Leaflet</span>
          </div>
          {(points.length > 0 || officerPts.length > 0) ? (
            <LiveMap alerts={points} officers={officerPts} height={340} />
          ) : (
            <p style={{ color: 'var(--muted)' }}>{t('dashboard.noGps')}</p>
          )}
        </div>

        <div className="panel">
          <div className="section-head"><h2>{t('dashboard.officerTracker')}<small>{available.length} available</small></h2></div>
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
          <div className="section-head"><h2>{t('dashboard.dispatchPanel')}<small>{active.length} in progress</small></h2></div>
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
          <div className="section-head"><h2>{t('dashboard.callbackQueue')}<small>pending acknowledgement</small></h2></div>
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

  const activeSosCount = sos.filter((s) => ['triggered', 'acknowledged', 'dispatched'].includes(s.status)).length;

  return (
    <div>
      <div className="page-head hero">
        <div>
          <h1>{t('dashboard.police')}</h1>
          <p>{t('dashboard.policeSub')}</p>
        </div>
        <div className="hero-meta">
          <span className="pill"><span className="dot blue" /> {mine.length} assigned</span>
          <span className="pill"><span className={`dot ${activeSosCount ? 'red' : 'green'}`} /> {activeSosCount} active SOS</span>
          <span className="pill"><Icon name="shield" size={14} /> {user?.region || 'on duty'}</span>
        </div>
      </div>

      <div className="cards kpi-grid">
        <div className="card kpi">
          <div className="kpi-top"><span className="kpi-icon blue"><Icon name="reports" size={18} /></span><span className="kpi-label">{t('dashboard.assignedToYou')}</span></div>
          <div className="kpi-value">{mine.length}</div>
          <div className="kpi-meta">In your queue</div>
        </div>
        <div className="card kpi">
          <div className="kpi-top"><span className="kpi-icon amber"><Icon name="audit" size={18} /></span><span className="kpi-label">{t('dashboard.unassigned')}</span></div>
          <div className="kpi-value">{open.length}</div>
          <div className="kpi-meta">Awaiting assignment</div>
        </div>
        <div className="card kpi">
          <div className="kpi-top"><span className="kpi-icon red"><Icon name="sos" size={18} /></span><span className="kpi-label">{t('dashboard.activeSosRegion')}</span></div>
          <div className="kpi-value">{activeSosCount}</div>
          <div className="kpi-meta">Live emergencies</div>
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <div className="section-head"><h2>{t('dashboard.assignedCases')}<small>{mine.length} cases</small></h2></div>
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
          <div className="section-head"><h2>{t('dashboard.unassignedQueue')}<small>take up next</small></h2></div>
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
        <div className="section-head">
          <h2>{t('dashboard.latestAnnouncements')}<small>regional briefings</small></h2>
          <a className="btn small ghost" href="/announcements">All →</a>
        </div>
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
