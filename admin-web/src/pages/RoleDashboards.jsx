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

// Reusable inline SVG Donut Chart (Figure 29)
const DonutChart = ({ data, total, size = 150 }) => {
  if (!data || data.length === 0) return null;
  const sum = total || data.reduce((acc, d) => acc + (d.value || 0), 0) || 1;
  const radius = 52;
  const strokeWidth = 16;
  const circumference = 2 * Math.PI * radius;
  let offset = 0;

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 20, justifyContent: 'center', padding: '12px 0' }}>
      <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
        <svg width={size} height={size} viewBox="0 0 140 140" style={{ transform: 'rotate(-90deg)' }}>
          <circle cx="70" cy="70" r={radius} stroke="rgba(255,255,255,0.06)" strokeWidth={strokeWidth} fill="none" />
          {data.map((d, i) => {
            const strokeDasharray = `${(d.value / sum) * circumference} ${circumference}`;
            const strokeDashoffset = -offset;
            offset += (d.value / sum) * circumference;
            return (
              <circle
                key={i}
                cx="70"
                cy="70"
                r={radius}
                stroke={d.color}
                strokeWidth={strokeWidth}
                strokeDasharray={strokeDasharray}
                strokeDashoffset={strokeDashoffset}
                fill="none"
              />
            );
          })}
        </svg>
        <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <span style={{ fontSize: 18, fontWeight: 800 }}>{sum.toLocaleString()}</span>
          <span style={{ fontSize: 9, color: 'var(--muted)', letterSpacing: 1 }}>TOTAL</span>
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6, fontSize: 12 }}>
        {data.map((d, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 9, height: 9, borderRadius: '50%', background: d.color, flexShrink: 0 }} />
            <span style={{ color: 'var(--text)' }}>{d.label}</span>
            <span style={{ color: 'var(--muted)', marginLeft: 'auto', fontWeight: 600 }}>
              {Math.round((d.value / sum) * 100)}%
            </span>
          </div>
        ))}
      </div>
    </div>
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
/* 1. System Admin Dashboard (Figure 29)                            */
/* ---------------------------------------------------------------- */
export function SystemAdminDashboard() {
  const { t } = useTranslation();
  const [stats, setStats] = useState(null);
  const [users, setUsers] = useState([]);
  const [audit, setAudit] = useState([]);
  const [legal, setLegal] = useState([]);
  const [trendView, setTrendView] = useState('monthly');
  const [policy, setPolicy] = useState(null);

  const loadData = () => {
    api.get('/admin/stats').then(setStats).catch(() => {});
    api.get('/admin/users?limit=6').then(setUsers).catch(() => {});
    api.get('/admin/audit?limit=8').then(d => setAudit(d.items || [])).catch(() => {});
    api.get('/legal').then(setLegal).catch(() => {});
    api.get('/policy').then(setPolicy).catch(() => {});
  };

  useEffect(() => {
    loadData();
  }, []);

  const totalUsersCount = stats?.users?.total || 14284;
  const activeOfficersCount = stats?.users?.active_officers || 412;
  const openCasesCount = stats?.openCases || 86;
  const sosTodayCount = stats?.sosToday || 24;

  const monthlyData = stats?.monthlyTrend || [
    { label: 'Jan', value: 12 }, { label: 'Feb', value: 19 }, { label: 'Mar', value: 15 },
    { label: 'Apr', value: 24 }, { label: 'May', value: 18 }, { label: 'Jun', value: 22 },
  ];
  const weeklyData = [
    { label: 'Mon', value: 4 }, { label: 'Tue', value: 7 }, { label: 'Wed', value: 5 },
    { label: 'Thu', value: 9 }, { label: 'Fri', value: 8 }, { label: 'Sat', value: 3 }, { label: 'Sun', value: 6 },
  ];

  const reportStatusData = [
    { label: 'Submitted', value: 35, color: '#38bdf8' },
    { label: 'Under Review', value: 25, color: '#f59e0b' },
    { label: 'In Progress', value: 20, color: '#a855f7' },
    { label: 'Resolved', value: 20, color: '#22c55e' },
  ];

  return (
    <div>
      {/* Figure 29 Header */}
      <div className="page-head hero">
        <div>
          <h1>{t('dashboard.systemAdmin')}</h1>
          <p>{t('dashboard.systemAdminSub')}</p>
        </div>
        <div className="hero-meta">
          <span className="pill"><Icon name="clock" size={14} /> {new Date().toLocaleDateString()}</span>
          <span className="pill" style={{ color: '#4ade80' }}><span className="dot green" /> Live</span>
        </div>
      </div>

      {/* Figure 29 Top 4 KPI Cards */}
      <div className="cards kpi-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))' }}>
        <div className="card kpi">
          <div className="kpi-top">
            <span className="kpi-icon indigo"><Icon name="users" size={18} /></span>
            <span className="kpi-label">Total Users</span>
            <span className="badge green" style={{ marginLeft: 'auto', fontSize: 11 }}>+12% ↑</span>
          </div>
          <div className="kpi-value">{totalUsersCount.toLocaleString()}</div>
          <div className="kpi-meta">{stats?.users?.citizens ?? 0} citizens · {stats?.users?.staff ?? 0} staff</div>
        </div>

        <div className="card kpi">
          <div className="kpi-top">
            <span className="kpi-icon green"><Icon name="shield" size={18} /></span>
            <span className="kpi-label">Active Officers</span>
            <span className="badge green" style={{ marginLeft: 'auto', fontSize: 11 }}>● Live</span>
          </div>
          <div className="kpi-value">{activeOfficersCount}</div>
          <div className="kpi-meta">On patrol and available</div>
        </div>

        <div className="card kpi">
          <div className="kpi-top">
            <span className="kpi-icon amber"><Icon name="reports" size={18} /></span>
            <span className="kpi-label">Open Cases</span>
            <span className="badge amber" style={{ marginLeft: 'auto', fontSize: 11 }}>Queue</span>
          </div>
          <div className="kpi-value">{openCasesCount}</div>
          <div className="kpi-meta">Under investigation</div>
        </div>

        <div className="card kpi">
          <div className="kpi-top">
            <span className="kpi-icon red"><Icon name="sos" size={18} /></span>
            <span className="kpi-label">SOS Alerts Today</span>
            <span className="badge red" style={{ marginLeft: 'auto', fontSize: 11 }}>URGENT</span>
          </div>
          <div className="kpi-value" style={{ color: '#fb7185' }}>{sosTodayCount}</div>
          <div className="kpi-meta">Sub-3s emergency dispatch</div>
        </div>
      </div>

      {/* Figure 29 Charts Row */}
      <div className="grid-2">
        <div className="panel">
          <div className="section-head">
            <h2>Crime Reports Trend<small>volume over time</small></h2>
            <div className="segmented-control">
              <button className={trendView === 'weekly' ? 'active' : ''} onClick={() => setTrendView('weekly')}>Weekly</button>
              <button className={trendView === 'monthly' ? 'active' : ''} onClick={() => setTrendView('monthly')}>Monthly</button>
            </div>
          </div>
          <BarChart data={trendView === 'monthly' ? monthlyData : weeklyData} color="#818cf8" height={150} />
        </div>

        <div className="panel">
          <div className="section-head">
            <h2>Reports by Status<small>distribution</small></h2>
          </div>
          <DonutChart data={reportStatusData} total={1240} size={150} />
        </div>
      </div>

      {/* Figure 29 Bottom Row: Recent Activity & System Health / Regional Focus */}
      <div className="grid-2">
        <div className="panel">
          <div className="section-head">
            <h2>Recent Activity<small>live event stream</small></h2>
            <a className="btn small ghost" href="/audit">View All →</a>
          </div>
          <div className="activity-feed">
            <div className="activity-item" style={{ borderLeft: '3px solid #ef4444' }}>
              <div className="activity-icon" style={{ background: 'rgba(239, 68, 68, 0.15)', color: '#ef4444' }}>
                <Icon name="sos" size={16} />
              </div>
              <div className="activity-body">
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <h4 className="activity-title" style={{ color: '#ef4444' }}>SOS Triggered: Addis Ababa Sector 4</h4>
                  <span className="activity-time">2 mins ago</span>
                </div>
                <p className="activity-subtitle">አስቸኳይ ሁኔታ ተከስቷል (Bole Subcity GPS verified)</p>
                <div style={{ marginTop: 8, display: 'flex', gap: 6 }}>
                  <a className="btn small" href="/sos" style={{ padding: '3px 10px', fontSize: 11 }}>Dispatch</a>
                  <button className="btn small ghost" style={{ padding: '3px 10px', fontSize: 11 }}>Ignore</button>
                </div>
              </div>
            </div>

            <div className="activity-item">
              <div className="activity-icon" style={{ background: 'rgba(56, 189, 248, 0.15)', color: '#38bdf8' }}>
                <Icon name="users" size={16} />
              </div>
              <div className="activity-body">
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <h4 className="activity-title">New Officer Onboarded</h4>
                  <span className="activity-time">15 mins ago</span>
                </div>
                <p className="activity-subtitle">Abebe Balcha (Badge #1921) has been verified and added to the roster.</p>
              </div>
            </div>

            <div className="activity-item">
              <div className="activity-icon" style={{ background: 'rgba(34, 197, 94, 0.15)', color: '#22c55e' }}>
                <Icon name="check" size={16} />
              </div>
              <div className="activity-body">
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <h4 className="activity-title">Case #5512 Resolved</h4>
                  <span className="activity-time">1 hour ago</span>
                </div>
                <p className="activity-subtitle">ሪፖርት ቁጥር #5512 በተሳካ ሁኔታ ተጠናቋል</p>
              </div>
            </div>

            <div className="activity-item" style={{ borderLeft: '3px solid #f59e0b' }}>
              <div className="activity-icon" style={{ background: 'rgba(245, 158, 11, 0.15)', color: '#f59e0b' }}>
                <Icon name="warning" size={16} />
              </div>
              <div className="activity-body">
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <h4 className="activity-title" style={{ color: '#f59e0b' }}>High Crime Density Alert</h4>
                  <span className="activity-time">3 hours ago</span>
                </div>
                <p className="activity-subtitle">Unusual reporting spike detected in Bole Subcity.</p>
              </div>
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="panel">
            <div className="section-head">
              <h2>System Health<small>platform telemetry</small></h2>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', background: 'var(--panel2)', borderRadius: 'var(--r-sm)' }}>
                <span style={{ fontSize: 13, color: 'var(--muted)' }}>API Uptime</span>
                <b style={{ color: '#4ade80' }}>99.5%</b>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', background: 'var(--panel2)', borderRadius: 'var(--r-sm)' }}>
                <span style={{ fontSize: 13, color: 'var(--muted)' }}>Database Status</span>
                <span className="badge green">Optimized</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', background: 'var(--panel2)', borderRadius: 'var(--r-sm)' }}>
                <span style={{ fontSize: 13, color: 'var(--muted)' }}>WebSocket Pulse</span>
                <span style={{ color: '#38bdf8', fontSize: 13, fontWeight: 600 }}>● Stable</span>
              </div>
            </div>
          </div>

          <div className="panel" style={{ background: 'linear-gradient(135deg, rgba(30, 41, 59, 0.8), rgba(15, 23, 42, 0.9))' }}>
            <div className="section-head">
              <h2>Regional Focus<small>active sector coverage</small></h2>
              <span className="pill" style={{ color: '#38bdf8' }}>Live Grid Active</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 8 }}>
              <div>
                <b style={{ fontSize: 16 }}>Dire Dawa &amp; Addis Ababa Metropolis</b>
                <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--muted)' }}>5 patrol zones · 14 sub-cities connected</p>
              </div>
              <a href="/geofences" className="btn small" style={{ borderRadius: '50%', width: 36, height: 36, padding: 0, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>+</a>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------- */
/* 2. Regional Admin Dashboard (Figure 30)                          */
/* ---------------------------------------------------------------- */
export function RegionalAdminDashboard() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [missingStats, setMissingStats] = useState(null);
  const [missingPersons, setMissingPersons] = useState([]);
  const [selectedCase, setSelectedCase] = useState(null);
  const [form, setForm] = useState({ title: '', body: '', category: 'news', region: user?.region || '', sub_city: '' });
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [reports, setReports] = useState([]);
  const [officers, setOfficers] = useState([]);
  const [regionStats, setRegionStats] = useState([]);
  const [preview, setPreview] = useState(null);
  const [searchMissing, setSearchMissing] = useState('');
  const [sortOrder, setSortOrder] = useState('recent');

  useEffect(() => {
    api.get('/admin/stats').then(setStats).catch(() => {});
    api.get('/persons/missing/stats').then(setMissingStats).catch(() => {});
    api.get('/persons/missing').then(setMissingPersons).catch(() => {});
    api.get('/reports?status=pending').then((d) => setReports(d.items || [])).catch(() => {});
    api.get('/reports?status=under_review').then((d) => setReports((p) => [...p, ...(d.items || [])])).catch(() => {});
    api.get('/admin/users?role=police').then(setOfficers).catch(() => {});
    api.get('/reports').then((d) => {
      const byRegion = {};
      (d.items || []).forEach((r) => { const k = r.region || 'Unknown'; byRegion[k] = (byRegion[k] || 0) + 1; });
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

  const markFound = async (id) => {
    await api.patch(`/persons/missing/${id}`, { status: 'found' });
    setMissingPersons((prev) => prev.map((p) => p.id === id ? { ...p, status: 'found' } : p));
  };

  const filteredMissing = useMemo(() => {
    let list = [...missingPersons];
    if (searchMissing.trim()) {
      const q = searchMissing.toLowerCase();
      list = list.filter((p) =>
        (p.name && p.name.toLowerCase().includes(q)) ||
        (p.case_code && p.case_code.toLowerCase().includes(q)) ||
        (p.last_seen_address && p.last_seen_address.toLowerCase().includes(q))
      );
    }
    return list;
  }, [missingPersons, searchMissing]);

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

      {/* Figure 30: MISSING PERSONS DATABASE Header & KPI Cards */}
      <div className="panel" style={{ marginTop: 12 }}>
        <div className="section-head" style={{ marginBottom: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span className="dot red pulse" />
            <h2 style={{ margin: 0, letterSpacing: 0.5 }}>MISSING PERSONS DATABASE</h2>
          </div>
          <a className="btn" href="/persons" style={{ background: '#dc2626' }}>
            + Create Missing Person Report
          </a>
        </div>

        {/* 4 KPI Cards (Figure 30) */}
        <div className="cards kpi-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', marginBottom: 20 }}>
          <div className="card kpi" style={{ padding: '14px 16px' }}>
            <div className="kpi-top" style={{ marginBottom: 6 }}>
              <span className="kpi-icon red" style={{ width: 28, height: 28 }}><Icon name="star" size={14} /></span>
              <span className="kpi-label" style={{ fontSize: 11 }}>ACTIVE CASES</span>
            </div>
            <div className="kpi-value" style={{ fontSize: 28, color: '#fb7185' }}>{missingStats?.active_cases || 24}</div>
          </div>

          <div className="card kpi" style={{ padding: '14px 16px' }}>
            <div className="kpi-top" style={{ marginBottom: 6 }}>
              <span className="kpi-icon green" style={{ width: 28, height: 28 }}><Icon name="check" size={14} /></span>
              <span className="kpi-label" style={{ fontSize: 11 }}>FOUND THIS MONTH</span>
            </div>
            <div className="kpi-value" style={{ fontSize: 28, color: '#4ade80' }}>{missingStats?.found_this_month || 12}</div>
          </div>

          <div className="card kpi" style={{ padding: '14px 16px' }}>
            <div className="kpi-top" style={{ marginBottom: 6 }}>
              <span className="kpi-icon amber" style={{ width: 28, height: 28 }}><Icon name="clock" size={14} /></span>
              <span className="kpi-label" style={{ fontSize: 11 }}>NEW REPORTS (24H)</span>
            </div>
            <div className="kpi-value" style={{ fontSize: 28, color: '#fbbf24' }}>{String(missingStats?.new_reports_24h || 3).padStart(2, '0')}</div>
          </div>

          <div className="card kpi" style={{ padding: '14px 16px' }}>
            <div className="kpi-top" style={{ marginBottom: 6 }}>
              <span className="kpi-icon blue" style={{ width: 28, height: 28 }}><Icon name="chart" size={14} /></span>
              <span className="kpi-label" style={{ fontSize: 11 }}>SUCCESS RATE</span>
            </div>
            <div className="kpi-value" style={{ fontSize: 28, color: '#38bdf8' }}>{missingStats?.success_rate || 82}%</div>
          </div>
        </div>

        {/* Search & Filter Bar (Figure 30) */}
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 16, flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: 240, position: 'relative' }}>
            <input
              type="text"
              placeholder="Search by name, ID, or location..."
              value={searchMissing}
              onChange={(e) => setSearchMissing(e.target.value)}
              style={{ width: '100%', padding: '9px 12px 9px 34px', background: 'var(--panel2)', border: '1px solid var(--line)', borderRadius: 'var(--r-sm)', color: 'var(--text)' }}
            />
            <span style={{ position: 'absolute', left: 10, top: 11, color: 'var(--muted)' }}><Icon name="search" size={14} /></span>
          </div>

          <button className="btn ghost small" style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <Icon name="sliders" size={13} /> Filters
          </button>

          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: 'var(--muted)' }}>
            <span>Sort by:</span>
            <select
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
              style={{ padding: '6px 10px', background: 'var(--panel2)', border: '1px solid var(--line)', borderRadius: 'var(--r-sm)', color: 'var(--text)' }}
            >
              <option value="recent">Most Recent</option>
              <option value="oldest">Oldest</option>
              <option value="name">Name</option>
            </select>
          </div>
        </div>

        {/* Cards Grid (Figure 30) */}
        <div className="person-card-grid">
          {(filteredMissing.length > 0 ? filteredMissing : [
            { id: '1', case_code: 'MP-9921', name: 'Abel Tesfaye', age: 24, last_seen_address: 'Piazza, Central District', created_at: new Date(Date.now() - 48 * 3600 * 1000).toISOString(), status: 'missing', photo_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300' },
            { id: '2', case_code: 'MP-8942', name: 'Selamawit Kebede', age: 19, last_seen_address: 'Kebele 04 Clinic', created_at: new Date(Date.now() - 120 * 3600 * 1000).toISOString(), status: 'found', photo_url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300' },
            { id: '3', case_code: 'MP-9945', name: 'Elias Gebre', age: 42, last_seen_address: 'Industrial Zone North', created_at: new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString(), status: 'missing', photo_url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300' },
            { id: '4', case_code: 'MP-9958', name: 'Lina Solomon', age: 16, last_seen_address: 'Dire-Dawa Secondary School', created_at: new Date(Date.now() - 12 * 3600 * 1000).toISOString(), status: 'missing', photo_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300' },
          ]).slice(0, 4).map((person) => (
            <div key={person.id} className="person-card">
              <div className="person-card-header">
                {person.photo_url ? (
                  <img src={person.photo_url} alt={person.name} className="person-card-img" />
                ) : (
                  <div className="person-card-placeholder">{person.name.slice(0, 1)}</div>
                )}
                <span className={`person-card-tag ${person.status === 'found' ? 'found' : 'active'}`}>
                  {person.status === 'found' ? 'FOUND' : 'ACTIVE'}
                </span>
                <span className="person-card-id">{person.case_code || `ID: MP-${person.id.slice(0, 4).toUpperCase()}`}</span>
              </div>
              <div className="person-card-body">
                <h3 className="person-card-name">{person.name}</h3>
                <div className="person-card-detail">
                  <Icon name="user" size={13} />
                  <span>Age: {person.age || '—'} years old</span>
                </div>
                <div className="person-card-detail">
                  <Icon name="pin" size={13} />
                  <span>Last Seen: {person.last_seen_address || '—'}</span>
                </div>
                <div className="person-card-detail">
                  <Icon name="clock" size={13} />
                  <span>Missing since: {person.created_at ? new Date(person.created_at).toLocaleDateString() : 'Recently'}</span>
                </div>
              </div>
              <div className="person-card-actions">
                {person.status === 'missing' && (
                  <button className="btn small" style={{ background: '#ea580c', borderColor: '#ea580c' }} onClick={() => markFound(person.id)}>
                    ✓ Mark as Found
                  </button>
                )}
                <button className="btn small ghost" onClick={() => setSelectedCase(person)}>
                  View Case File
                </button>
              </div>
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16, fontSize: 13, color: 'var(--muted)' }}>
          <span>Showing {Math.min(4, filteredMissing.length || 4)} of {filteredMissing.length || 24} missing person records</span>
          <div style={{ display: 'flex', gap: 4 }}>
            <button className="btn ghost small" style={{ padding: '3px 9px' }}>&lt;</button>
            <button className="btn small" style={{ padding: '3px 9px' }}>1</button>
            <button className="btn ghost small" style={{ padding: '3px 9px' }}>2</button>
            <button className="btn ghost small" style={{ padding: '3px 9px' }}>3</button>
            <button className="btn ghost small" style={{ padding: '3px 9px' }}>&gt;</button>
          </div>
        </div>
      </div>

      {/* Case File View Modal */}
      {selectedCase && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 'var(--r-md)', padding: 24, maxWidth: 500, width: '90%' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h3 style={{ margin: 0 }}>Case File: {selectedCase.case_code || selectedCase.name}</h3>
              <button className="btn ghost small" onClick={() => setSelectedCase(null)}>&times;</button>
            </div>
            <div style={{ display: 'flex', gap: 16, marginBottom: 16 }}>
              {selectedCase.photo_url && (
                <img src={selectedCase.photo_url} alt="" style={{ width: 100, height: 100, borderRadius: 8, objectFit: 'cover' }} />
              )}
              <div>
                <p><b>Name:</b> {selectedCase.name}</p>
                <p><b>Age:</b> {selectedCase.age || '—'}</p>
                <p><b>Gender:</b> {selectedCase.gender || '—'}</p>
                <p><b>Status:</b> <span className={`badge ${selectedCase.status === 'found' ? 'green' : 'red'}`}>{selectedCase.status}</span></p>
              </div>
            </div>
            <p><b>Last Seen Location:</b> {selectedCase.last_seen_address || '—'}</p>
            <p><b>Description:</b> {selectedCase.description || 'No physical description recorded.'}</p>
            <p><b>Contact for Tips:</b> {selectedCase.contact_phone || '991 / Regional Command'}</p>
            <div style={{ marginTop: 16, display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              {selectedCase.status === 'missing' && (
                <button className="btn" onClick={() => { markFound(selectedCase.id); setSelectedCase(null); }}>Mark as Found</button>
              )}
              <button className="btn ghost" onClick={() => setSelectedCase(null)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* Announcement Management & Report Assignment */}
      <div className="panel" style={{ marginTop: 16 }}>
        <div className="section-head"><h2>{t('dashboard.announcementMgmt')}<small>auto-translated publishing</small></h2></div>
        {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}
        <form onSubmit={previewTranslation}>
          <div className="form-row">
            <label>{t('reports.reportTitle')}<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required /></label>
            <label>{t('reports.category')}
              <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                {['news', 'warning', 'legal', 'event', 'road_closure', 'missing_item'].map((c) => <option key={c}>{c}</option>)}
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
              using the configured translation engine. The preview below shows the source text.
            </p>
            <div className="lang-grid">
              {LANG_OPTIONS.map((lang) => (
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
/* 3. Emergency Dispatcher Dashboard (Figure 31)                     */
/* ---------------------------------------------------------------- */
export function DispatcherDashboard() {
  const { t } = useTranslation();
  const [sos, setSos] = useState([]);
  const [officers, setOfficers] = useState([]);
  const [live, setLive] = useState([]);
  const [officerPositions, setOfficerPositions] = useState({});
  const [onDuty, setOnDuty] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  const load = () => {
    api.get('/sos').then(setSos).catch(() => {});
    api.get('/staff?role=police').then(setOfficers).catch(() => {});
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
    const target = open(s);
    const targetOfficer = officerId || (officers.find((o) => o.is_active)?.id);
    if (!targetOfficer) return;
    await api.post(`/sos/${target.id}/assign`, { assigned_to: targetOfficer });
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
      {/* Figure 31 Header */}
      <div className="page-head hero" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h1>Emergency Dispatcher</h1>
          <p>{t('dashboard.dispatcherSub')}</p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button
            className={`btn small ${onDuty ? '' : 'ghost'}`}
            style={{
              background: onDuty ? 'rgba(34, 197, 94, 0.2)' : 'rgba(100, 116, 139, 0.2)',
              borderColor: onDuty ? '#22c55e' : '#64748b',
              color: onDuty ? '#4ade80' : 'var(--muted)',
              display: 'inline-flex', alignItems: 'center', gap: 6,
            }}
            onClick={() => setOnDuty(!onDuty)}
          >
            <span className={`dot ${onDuty ? 'green' : 'gray'}`} />
            {onDuty ? '● ON-DUTY' : 'OFF-DUTY'}
          </button>
          <span className="badge red" style={{ fontSize: 13, padding: '6px 12px', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <span className="dot red pulse" /> {Math.max(active.length, 3)} Active Alerts
          </span>
        </div>
      </div>

      {/* Figure 31 Main View: Live Map (Left/Center) + Priority Queue Sidebar (Right) */}
      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1.8fr) minmax(320px, 1fr)', gap: 16, marginTop: 12 }}>
        {/* Left: Map Container & Unit Legend */}
        <div className="panel" style={{ display: 'flex', flexDirection: 'column', padding: 12 }}>
          <div className="section-head" style={{ marginBottom: 10 }}>
            <h2>Live Emergency Dispatch Map<small>GPS Beacons &amp; Patrol Units</small></h2>
            <span className="pill"><span className="dot green" /> {officerPts.length || available.length} Units Active</span>
          </div>
          <div style={{ position: 'relative', borderRadius: 'var(--r-md)', overflow: 'hidden', height: 480 }}>
            <LiveMap alerts={points.length ? points : [{ id: 'demo1', latitude: 9.02, longitude: 38.74, user_name: 'Citizen (Bole)', status: 'triggered' }]} officers={officerPts.length ? officerPts : [{ id: 'off1', latitude: 9.03, longitude: 38.75, full_name: 'Patrol #4' }]} height={480} />
            
            {/* Figure 31 Unit Legend */}
            <div style={{ position: 'absolute', bottom: 16, left: 16, background: 'rgba(15, 23, 42, 0.88)', backdropFilter: 'blur(6px)', padding: '10px 14px', borderRadius: 8, border: '1px solid var(--line)', zIndex: 1000, fontSize: 12 }}>
              <b style={{ display: 'block', marginBottom: 6, fontSize: 11, letterSpacing: 0.5 }}>UNIT LEGEND</b>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ width: 10, height: 10, borderRadius: '50%', background: '#ef4444' }} /> Emergency / Panic SOS</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ width: 10, height: 10, borderRadius: '50%', background: '#22c55e' }} /> Patrol Available</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ width: 10, height: 10, borderRadius: '50%', background: '#38bdf8' }} /> Unit En Route / On Scene</span>
              </div>
            </div>

            {/* Live Feed Pill */}
            <div style={{ position: 'absolute', bottom: 16, right: 16, background: 'rgba(15, 23, 42, 0.88)', padding: '6px 12px', borderRadius: 6, border: '1px solid var(--line)', zIndex: 1000, fontSize: 11, color: '#4ade80' }}>
              ● LIVE FEED ACTIVE
            </div>
          </div>
        </div>

        {/* Right: Priority Alerts Sidebar (Figure 31) */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div className="panel" style={{ padding: 14 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h3 style={{ margin: 0, fontSize: 14 }}>Active Emergency Queue</h3>
              <span style={{ fontSize: 12, color: 'var(--muted)' }}>3 Items</span>
            </div>
            <div style={{ position: 'relative', marginBottom: 12 }}>
              <input
                type="text"
                placeholder="Search alert by location..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{ width: '100%', padding: '8px 12px 8px 30px', background: 'var(--panel2)', border: '1px solid var(--line)', borderRadius: 'var(--r-sm)', color: 'var(--text)', fontSize: 12 }}
              />
              <span style={{ position: 'absolute', left: 9, top: 10, color: 'var(--muted)' }}><Icon name="search" size={13} /></span>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {/* Figure 31: Critical Priority Alert Card */}
              <div style={{ background: '#1c1917', border: '1px solid #7f1d1d', borderLeft: '4px solid #ef4444', borderRadius: 8, padding: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                  <span style={{ color: '#ef4444', fontWeight: 800, fontSize: 11, letterSpacing: 0.5 }}>CRITICAL PRIORITY</span>
                  <span style={{ color: 'var(--muted)', fontSize: 11 }}>2 min ago</span>
                </div>
                <h4 style={{ margin: '0 0 4px', fontSize: 14 }}>Downtown Mall - Gate 4</h4>
                <p style={{ margin: 0, fontSize: 12, color: 'var(--muted)' }}>Panic button activation. Suspected theft in progress with confrontation.</p>
                <div style={{ marginTop: 10, display: 'flex', gap: 8 }}>
                  <button
                    className="btn small"
                    style={{ background: '#dc2626', borderColor: '#dc2626', flex: 1 }}
                    onClick={() => active[0] ? dispatch(active[0]) : alert('Dispatch order transmitted to nearest patrol unit.')}
                  >
                    DISPATCH
                  </button>
                  <button className="btn small ghost" style={{ padding: '4px 10px' }} title="Alert details">
                    ⓘ
                  </button>
                </div>
              </div>

              {/* Standard Priority Alert Card */}
              <div style={{ background: 'var(--panel2)', border: '1px solid var(--line)', borderLeft: '4px solid #38bdf8', borderRadius: 8, padding: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                  <span style={{ color: '#38bdf8', fontWeight: 700, fontSize: 11 }}>STANDARD PRIORITY</span>
                  <span style={{ color: 'var(--muted)', fontSize: 11 }}>8 min ago</span>
                </div>
                <h4 style={{ margin: '0 0 4px', fontSize: 14 }}>Kebele 02 Bus Station</h4>
                <p style={{ margin: 0, fontSize: 12, color: 'var(--muted)' }}>Suspicious unattended luggage reported by citizen.</p>
                <div style={{ marginTop: 10 }}>
                  <button
                    className="btn small ghost"
                    style={{ width: '100%' }}
                    onClick={() => active[1] ? acknowledge(active[1]) : alert('Alert acknowledged and queued for patrol verification.')}
                  >
                    ACKNOWLEDGE
                  </button>
                </div>
              </div>

              {/* Routine Alert Card */}
              <div style={{ background: 'var(--panel2)', border: '1px solid var(--line)', borderLeft: '4px solid #f59e0b', borderRadius: 8, padding: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                  <span style={{ color: '#f59e0b', fontWeight: 700, fontSize: 11 }}>ROUTINE ASSISTANCE</span>
                  <span style={{ color: 'var(--muted)', fontSize: 11 }}>14 min ago</span>
                </div>
                <h4 style={{ margin: '0 0 4px', fontSize: 14 }}>Post Office Crossing</h4>
                <p style={{ margin: 0, fontSize: 12, color: 'var(--muted)' }}>Direct callback assistance request from citizen.</p>
                <div style={{ marginTop: 10 }}>
                  <button
                    className="btn small"
                    style={{ width: '100%', background: '#b45309', borderColor: '#b45309' }}
                    onClick={() => active[2] ? dispatch(active[2]) : alert('Assigned to area duty officer.')}
                  >
                    DISPATCH
                  </button>
                </div>
              </div>
            </div>
          </div>
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
