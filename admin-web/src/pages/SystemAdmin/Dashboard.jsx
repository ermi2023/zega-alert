import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import { api } from '../../api/client';

/**
 * System Admin Dashboard — global overview of the entire ZEGA-ALERT platform.
 * Spec §2: per-role counts, active/suspended, recent activity feed, legal
 * overview, audit/notification totals. NOT mixed with the Regional Admin
 * dashboard — this view is platform telemetry, the Regional Admin view is
 * operational case-work.
 */
export default function SystemAdminDashboardPage() {
  const { t } = useTranslation();
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState('');

  const load = async () => {
    setLoading(true);
    setErr('');
    try {
      const data = await api.get('/admin/stats');
      setStats(data);
    } catch (e) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => { load(); }, []);

  if (loading) return <div className="loading">{t('loading.default', { defaultValue: 'Loading…' })}</div>;
  if (err)    return <div className="msg err">{err}</div>;
  if (!stats) return null;

  const u = stats.users || {};
  const byRole = u.byRole || {};
  const legal = stats.legalOverview || { total: 0, published: 0, draft: 0, under_review: 0 };
  const audit = stats.audit || { total: 0, last_24h: 0 };
  const notifications = stats.notifications || { total: 0, unread: 0 };
  const activity = stats.recentActivity || [];

  // Donut chart segments: share of each role out of total users.
  const roleColors = {
    system_admin: '#183C59', regional_admin: '#2f5a7e', dispatcher: '#38bdf8',
    police: '#22c55e', citizen: '#9bc1de',
  };
  const totalUsers = u.total || 0;
  const segments = Object.entries(byRole).map(([role, v]) => ({
    role, n: v.total || 0,
    color: roleColors[role] || '#888',
  })).filter(s => s.n > 0);

  // Build the SVG donut.
  let cum = 0;
  const R = 50, C = 2 * Math.PI * R;
  const arcs = segments.map(s => {
    const frac = s.n / totalUsers;
    const dash = frac * C;
    const arc = { ...s, dash, gap: C - dash, offset: -cum * C };
    cum += frac;
    return arc;
  });

  const recentActions = [
    'create_user','update_user','delete_user','suspend_user','activate_user','change_role',
    'set_security_policy','update_config','create_legal','update_legal','review_legal','publish_legal','delete_legal',
    'login','logout','change_password','reset_password','create_sos','update_sos_status',
  ];
  const actionLabel = (a) => a.replace(/_/g, ' ');
  const actionColor = (a) => {
    if (a.includes('delete')) return 'red';
    if (a.includes('suspend')) return 'red';
    if (a.includes('create') || a.includes('publish')) return 'green';
    if (a.includes('login') || a.includes('update') || a.includes('change')) return 'blue';
    return 'blue';
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('systemAdmin.dashboard.title', { defaultValue: 'System Admin Dashboard' })}</h1>
          <p>{t('systemAdmin.dashboard.subtitle', { defaultValue: 'Global overview of the ZEGA-ALERT platform' })}</p>
        </div>
        <button className="btn ghost" onClick={load}>↻ {t('systemAdmin.dashboard.refresh', { defaultValue: 'Refresh' })}</button>
      </div>

      {/* KPI row — user totals + active/suspended + audit/notification counts */}
      <div className="grid-4">
        <KpiCard label={t('systemAdmin.dashboard.totalUsers', { defaultValue: 'Total Users' })} value={u.total || 0} sub={`${u.active || 0} active · ${u.suspended || 0} suspended`} color="#183C59" />
        <KpiCard label={t('systemAdmin.dashboard.staffAccounts', { defaultValue: 'Staff Accounts' })} value={u.staff || 0} sub={`${u.active_officers || 0} active officers`} color="#2f5a7e" />
        <KpiCard label={t('systemAdmin.dashboard.auditEvents', { defaultValue: 'Audit Events' })} value={audit.total || 0} sub={`${audit.last_24h || 0} in last 24h`} color="#38bdf8" link="/admin/audit" />
        <KpiCard label={t('systemAdmin.dashboard.openCases', { defaultValue: 'Open Cases' })} value={stats.openCases || 0} sub={`${stats.totalReports || 0} reports total`} color="#f59e0b" />
      </div>

      <div className="grid-2">
        {/* User distribution by role — donut */}
        <div className="panel">
          <h2>{t('systemAdmin.dashboard.usersByRole', { defaultValue: 'Users by Role' })}</h2>
          <div style={{ display: 'flex', alignItems: 'center', gap: 24, flexWrap: 'wrap' }}>
            <svg width="140" height="140" viewBox="0 0 140 140" style={{ flex: 'none' }}>
              <g transform="translate(70,70) rotate(-90)">
                <circle r={R} fill="none" stroke="rgba(255,255,255,.06)" strokeWidth="14" />
                {arcs.map((a, i) => (
                  <circle key={i} r={R} fill="none" stroke={a.color} strokeWidth="14"
                    strokeDasharray={`${a.dash} ${a.gap}`} strokeDashoffset={a.offset} />
                ))}
              </g>
              <text x="70" y="68" textAnchor="middle" fontSize="22" fontWeight="800" fill="var(--text)">{totalUsers}</text>
              <text x="70" y="86" textAnchor="middle" fontSize="9" fill="var(--muted)">USERS</text>
            </svg>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, flex: 1, minWidth: 180 }}>
              {segments.map(s => (
                <div key={s.role} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                  <span style={{ width: 10, height: 10, borderRadius: 2, background: s.color }} />
                  <span style={{ flex: 1, textTransform: 'capitalize' }}>{s.role.replace(/_/g, ' ')}</span>
                  <b>{s.n}</b>
                  <span style={{ color: 'var(--muted)', fontSize: 11 }}>{totalUsers ? Math.round(s.n / totalUsers * 100) : 0}%</span>
                </div>
              ))}
            </div>
          </div>
          <Link to="/admin/users" className="btn ghost small" style={{ marginTop: 14 }}>{t('systemAdmin.dashboard.manageUsers', { defaultValue: 'Manage users →' })}</Link>
        </div>

        {/* Account status bar */}
        <div className="panel">
          <h2>{t('systemAdmin.dashboard.accountStatus', { defaultValue: 'Account Status' })}</h2>
          <BarRow label={t('systemAdmin.dashboard.active', { defaultValue: 'Active' })} value={u.active || 0} total={u.total || 1} color="#22c55e" />
          <BarRow label={t('systemAdmin.dashboard.suspended', { defaultValue: 'Suspended' })} value={u.suspended || 0} total={u.total || 1} color="#ef4444" />
          <div style={{ marginTop: 18, fontSize: 12, color: 'var(--muted)' }}>
            {t('systemAdmin.dashboard.byRole', { defaultValue: 'Breakdown by role:' })}
          </div>
          <table style={{ marginTop: 8, width: '100%', fontSize: 13 }}>
            <thead><tr><th style={{ textAlign: 'left' }}>Role</th><th>Total</th><th>Active</th><th>Suspended</th></tr></thead>
            <tbody>
              {['system_admin','regional_admin','dispatcher','police','citizen'].map(r => {
                const v = byRole[r] || { total: 0, active: 0, suspended: 0 };
                return (
                  <tr key={r}>
                    <td style={{ textTransform: 'capitalize' }}>{r.replace(/_/g, ' ')}</td>
                    <td style={{ textAlign: 'center' }}>{v.total}</td>
                    <td style={{ textAlign: 'center', color: '#22c55e' }}>{v.active}</td>
                    <td style={{ textAlign: 'center', color: v.suspended ? '#ef4444' : 'var(--muted)' }}>{v.suspended}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      <div className="grid-2">
        {/* Legal content overview */}
        <div className="panel">
          <h2>{t('systemAdmin.dashboard.legalOverview', { defaultValue: 'Legal Content Overview' })}</h2>
          <div className="grid-4" style={{ gap: 10, marginTop: 8 }}>
            <KpiCard small label={t('systemAdmin.dashboard.total', { defaultValue: 'Total' })} value={legal.total || 0} color="#183C59" />
            <KpiCard small label={t('systemAdmin.dashboard.published', { defaultValue: 'Published' })} value={legal.published || 0} color="#22c55e" />
            <KpiCard small label={t('systemAdmin.dashboard.draft', { defaultValue: 'Draft' })} value={legal.draft || 0} color="#f59e0b" />
            <KpiCard small label={t('systemAdmin.dashboard.underReview', { defaultValue: 'Under Review' })} value={legal.under_review || 0} color="#38bdf8" />
          </div>
          <Link to="/admin/legal" className="btn ghost small" style={{ marginTop: 14 }}>{t('systemAdmin.dashboard.manageLegal', { defaultValue: 'Manage legal content →' })}</Link>
        </div>

        {/* SOS / Reports summary */}
        <div className="panel">
          <h2>{t('systemAdmin.dashboard.platformHealth', { defaultValue: 'Platform Activity' })}</h2>
          <BarRow label={t('systemAdmin.dashboard.sosToday', { defaultValue: 'SOS alerts today' })} value={stats.sosToday || 0} total={Math.max(stats.sosToday || 1, 10)} color="#ef4444" />
          <BarRow label={t('systemAdmin.dashboard.openCases', { defaultValue: 'Open cases' })} value={stats.openCases || 0} total={Math.max(stats.totalReports || 1, 10)} color="#f59e0b" />
          <BarRow label={t('systemAdmin.dashboard.unreadNotifications', { defaultValue: 'Unread notifications' })} value={notifications.unread || 0} total={Math.max(notifications.total || 1, 10)} color="#38bdf8" />
          <BarRow label={t('systemAdmin.dashboard.missingPersons', { defaultValue: 'Missing persons' })} value={(stats.missingPersons && stats.missingPersons.missing) || 0} total={Math.max((stats.missingPersons && (stats.missingPersons.missing + stats.missingPersons.found)) || 1, 10)} color="#a855f7" />
        </div>
      </div>

      {/* Recent activity feed — real audit_log rows */}
      <div className="panel">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2>{t('systemAdmin.dashboard.recentActivity', { defaultValue: 'Recent System Activity' })}</h2>
          <Link to="/admin/audit" className="btn ghost small">{t('systemAdmin.dashboard.viewAll', { defaultValue: 'View all audit logs →' })}</Link>
        </div>
        {activity.length === 0 && <p style={{ color: 'var(--muted)' }}>{t('systemAdmin.dashboard.noActivity', { defaultValue: 'No recent activity.' })}</p>}
        <table style={{ marginTop: 8, width: '100%', fontSize: 13 }}>
          <thead><tr><th style={{ textAlign: 'left' }}>When</th><th style={{ textAlign: 'left' }}>Actor</th><th style={{ textAlign: 'left' }}>Action</th><th style={{ textAlign: 'left' }}>Entity</th><th style={{ textAlign: 'left' }}>IP</th></tr></thead>
          <tbody>
            {activity.map(a => {
              const isAuditedAction = recentActions.includes(a.action);
              return (
                <tr key={a.id}>
                  <td style={{ color: 'var(--muted)', fontFamily: 'monospace', fontSize: 11 }}>{a.created_at ? new Date(a.created_at).toLocaleString() : '—'}</td>
                  <td>{a.actor_name || 'system'}</td>
                  <td><span className={`badge ${actionColor(a.action)}`}>{actionLabel(a.action)}</span></td>
                  <td style={{ color: 'var(--muted)' }}>{a.entity || '—'}</td>
                  <td style={{ fontFamily: 'monospace', fontSize: 11 }}>{a.ip_address || '—'}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function KpiCard({ label, value, sub, color, link, small }) {
  const body = (
    <div className="kpi-card" style={{ background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 'var(--r-md)', padding: small ? 12 : 16, display: 'flex', flexDirection: 'column', gap: 4 }}>
      <div style={{ fontSize: small ? 10 : 11, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: 1 }}>{label}</div>
      <div style={{ fontSize: small ? 22 : 30, fontWeight: 800, color, lineHeight: 1.1 }}>{value}</div>
      {sub && <div style={{ fontSize: 11, color: 'var(--muted)' }}>{sub}</div>}
    </div>
  );
  return link ? <Link to={link} style={{ textDecoration: 'none' }}>{body}</Link> : body;
}

function BarRow({ label, value, total, color }) {
  const pct = total ? Math.min(100, Math.round(value / total * 100)) : 0;
  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
        <span>{label}</span><b>{value}</b>
      </div>
      <div style={{ height: 8, background: 'rgba(255,255,255,.06)', borderRadius: 4, overflow: 'hidden' }}>
        <div style={{ width: `${pct}%`, height: '100%', background: color, transition: 'width .3s' }} />
      </div>
    </div>
  );
}
