/**
 * System Activity Monitoring — read-only view of administrative activities
 * pulled from the audit_log (spec §10). This uses the SAME audit_log
 * infrastructure as the Audit Logs page (spec §8) — it is NOT a duplicate
 * recording system, just a different filter that surfaces administrative
 * actions (user/role/config/legal/security changes) rather than every event.
 */
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../../api/client';

// Admin-only action keys (spec §8.3 list).
const ADMIN_ACTIONS = [
  'create_user','update_user','delete_user','suspend_user','activate_user','change_role',
  'set_security_policy','update_config',
  'create_legal','update_legal','review_legal','publish_legal','delete_legal',
  'change_password','reset_password',
];

export default function ActivityPage() {
  const { t } = useTranslation();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState('');

  const load = async () => {
    setLoading(true); setErr('');
    try {
      // Fetch a larger page and filter to admin-only actions on the client.
      const data = await api.get('/admin/audit?limit=100');
      const all = data?.items || [];
      setItems(all.filter(r => ADMIN_ACTIONS.includes(r.action)));
    } catch (e) { setErr(e.message); }
    finally { setLoading(false); }
  };
  useEffect(() => { load(); }, []);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('systemAdmin.activity.title', { defaultValue: 'System Activity Monitoring' })}</h1>
          <p>{t('systemAdmin.activity.subtitle', { defaultValue: 'Administrative activities only — uses the same audit_log infrastructure as the Audit Logs page' })}</p>
        </div>
        <button className="btn ghost" onClick={load}>↻ Refresh</button>
      </div>

      {err && <div className="msg err">{err}</div>}

      <div className="panel">
        {loading && <p style={{ color: 'var(--muted)' }}>Loading…</p>}
        {!loading && items.length === 0 && <p style={{ color: 'var(--muted)' }}>{t('systemAdmin.activity.noActivity', { defaultValue: 'No administrative activity recorded yet.' })}</p>}

        {items.length > 0 && (
          <table>
            <thead>
              <tr>
                <th style={{ textAlign: 'left' }}>When</th>
                <th style={{ textAlign: 'left' }}>Actor</th>
                <th style={{ textAlign: 'left' }}>Action</th>
                <th style={{ textAlign: 'left' }}>Target</th>
                <th style={{ textAlign: 'left' }}>IP</th>
                <th style={{ textAlign: 'left' }}>Detail</th>
              </tr>
            </thead>
            <tbody>
              {items.map(a => {
                let detail = '';
                try {
                  const d = typeof a.detail === 'string' ? JSON.parse(a.detail) : a.detail;
                  if (a.action === 'change_role' && d?.from && d?.to) detail = `${d.from} → ${d.to}`;
                  else if (a.action === 'set_security_policy' && d?.diff) detail = Object.keys(d.diff).join(', ');
                  else if (a.action === 'update_config' && d?.setting) detail = `${d.setting}: ${String(d.from).slice(0, 30)} → ${String(d.to).slice(0, 30)}`;
                  else if (a.action === 'create_user' && d?.full_name) detail = `${d.full_name} (${d.role})`;
                  else if (a.action === 'delete_user' && d?.full_name) detail = `${d.full_name} (${d.role})`;
                  else if (a.action === 'review_legal' && d?.title) detail = `${d.title}: ${d.from} → ${d.to}`;
                  else if (d?.method) detail = `via ${d.method}`;
                } catch {}
                return (
                  <tr key={a.id}>
                    <td style={{ color: 'var(--muted)', fontFamily: 'monospace', fontSize: 11 }}>{a.created_at ? new Date(a.created_at).toLocaleString() : '—'}</td>
                    <td>{a.full_name || a.actor_name || 'system'}</td>
                    <td><span className="badge blue">{a.action.replace(/_/g, ' ')}</span></td>
                    <td style={{ color: 'var(--muted)' }}>{a.entity || '—'}{a.entity_id ? ` · ${String(a.entity_id).slice(0, 8)}` : ''}</td>
                    <td style={{ fontFamily: 'monospace', fontSize: 11 }}>{a.ip_address || '—'}</td>
                    <td style={{ fontSize: 12, color: 'var(--muted)' }}>{detail}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
