import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import { useAuth } from '../context/AuthContext';

const badge = (v) => ({ draft: 'gray', pending: 'amber', submitted: 'amber', under_review: 'blue', assigned: 'blue', in_progress: 'amber', verified: 'green', resolved: 'green', rejected: 'red', closed: 'gray' }[v] || 'gray');
const sev = (v) => ({ low: 'gray', medium: 'blue', high: 'amber', critical: 'red' }[v] || 'gray');
const STATUSES = ['draft', 'pending', 'submitted', 'under_review', 'assigned', 'in_progress', 'verified', 'rejected', 'resolved', 'closed'];

export default function Reports() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const canAssign = ['regional_admin', 'system_admin'].includes(user?.role);
  const [rows, setRows] = useState([]);
  const [status, setStatus] = useState('');
  const [region, setRegion] = useState('');
  const [q, setQ] = useState('');
  const [officers, setOfficers] = useState([]);
  const [detail, setDetail] = useState(null);
  const [notes, setNotes] = useState('');
  const [history, setHistory] = useState([]);

  const load = () => api.get(`/reports?status=${status}&region=${encodeURIComponent(region)}&q=${q}`).then((d) => setRows(d.items));
  useEffect(() => { load(); }, [status, region, q]);

  useEffect(() => {
    if (canAssign) api.get('/admin/users?role=police').then(setOfficers).catch(() => {});
  }, [canAssign]);

  const assign = async (r, officerId) => {
    if (!officerId) return;
    await api.patch(`/reports/${r.id}/status`, {
      status: ['draft', 'pending', 'submitted'].includes(r.status) ? 'under_review' : r.status,
      assigned_to: officerId,
    });
    load();
  };

  const setStatusNow = async (id, next, investigationNotes) => {
    await api.patch(`/reports/${id}/status`, { status: next, response_notes: investigationNotes || undefined });
    setNotes('');
    load();
  };

  const showDetail = async (r) => {
    setDetail(r);
    setNotes('');
    try { setHistory(await api.get(`/reports/${r.id}/history`)); } catch { setHistory([]); }
  };

  return (
    <div>
      <div className="page-head">
        <div><h1>{t('reports.title')}</h1><p>{t('reports.subtitle')}</p></div>
      </div>
      <div className="filters">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">{t('reports.allStatuses')}</option>
          {STATUSES.map((s) => <option key={s}>{s}</option>)}
        </select>
        <input placeholder="Region…" value={region} onChange={(e) => setRegion(e.target.value)} />
        <input placeholder="Search title/description…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      <div className="panel">
        <table>
          <thead><tr><th>{t('reports.reported')}</th><th>{t('reports.reportTitle')}</th><th>{t('reports.category')}</th><th>{t('reports.severity')}</th><th>{t('reports.location')}</th><th>{t('reports.status')}</th>{canAssign && <th>Assign to</th>}<th>{t('reports.actions')}</th></tr></thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} style={{ cursor: 'pointer' }} onClick={() => showDetail(r)}>
                <td>{new Date(r.reported_at).toLocaleDateString()}</td>
                <td>
                  <b>{r.title}</b>
                  <div style={{ color: 'var(--muted)', fontSize: 12 }}>{r.is_anonymous ? t('reports.anonymous') : (r.reporter_name || '—')}</div>
                </td>
                <td>{r.category}</td>
                <td><span className={`badge ${sev(r.severity)}`}>{r.severity}</span></td>
                <td>{r.sub_city || r.region || '—'}</td>
                <td><span className={`badge ${badge(r.status)}`}>{r.status}</span></td>
                {canAssign && (
                  <td onClick={(e) => e.stopPropagation()}>
                    <select defaultValue="" onChange={(e) => assign(r, e.target.value)}>
                      <option value="" disabled>{r.assigned_to ? 'Reassign…' : 'Select officer…'}</option>
                      {officers.map((o) => <option key={o.id} value={o.id}>{o.full_name}</option>)}
                    </select>
                  </td>
                )}
                <td onClick={(e) => e.stopPropagation()}>
                  {r.status === 'pending' && <button className="btn small" onClick={() => setStatusNow(r.id, 'under_review')}>{t('reports.review')}</button>}
                  {r.status === 'under_review' && <button className="btn small" onClick={() => setStatusNow(r.id, 'verified')}>{t('reports.verify')}</button>}
                  {r.status === 'verified' && <button className="btn small" onClick={() => setStatusNow(r.id, 'resolved')}>{t('reports.resolve')}</button>}
                  {['pending', 'under_review', 'verified'].includes(r.status) && (
                    <button className="btn small danger" style={{ marginLeft: 6 }} onClick={() => setStatusNow(r.id, 'rejected')}>{t('reports.reject')}</button>
                  )}
                </td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={canAssign ? 8 : 7} style={{ color: 'var(--muted)' }}>{t('reports.noReports')}</td></tr>}
          </tbody>
        </table>
      </div>

      {detail && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 50, display: 'grid', placeItems: 'center' }}
          onClick={() => setDetail(null)}>
          <div className="panel" style={{ maxWidth: 600, width: '90%', maxHeight: '80vh', overflow: 'auto' }}
            onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h2 style={{ margin: 0 }}>{t('reports.detail')}</h2>
              <button className="btn ghost" onClick={() => setDetail(null)}>{t('reports.close')}</button>
            </div>
            <div className="form-row" style={{ marginBottom: 12 }}>
              <div><strong>Title</strong><p>{detail.title}</p></div>
              <div><strong>Status</strong><p><span className={`badge ${badge(detail.status)}`}>{detail.status}</span></p></div>
              <div><strong>Severity</strong><p><span className={`badge ${sev(detail.severity)}`}>{detail.severity}</span></p></div>
            </div>
            <div className="form-row" style={{ marginBottom: 12 }}>
              <div><strong>Category</strong><p>{detail.category}</p></div>
              <div><strong>Region</strong><p>{detail.region || '—'}</p></div>
              <div><strong>Sub-city</strong><p>{detail.sub_city || '—'}</p></div>
            </div>
            <div style={{ marginBottom: 12 }}>
              <strong>{t('reports.reporter')}</strong>
              <p>{detail.is_anonymous ? t('reports.anonymous') : (detail.reporter_name || detail.reporter_id || '—')}</p>
            </div>
            <div style={{ marginBottom: 12 }}>
              <strong>{t('reports.description')}</strong>
              <p style={{ color: 'var(--muted)' }}>{detail.description || t('reports.noDescription')}</p>
            </div>
            {detail.latitude && detail.longitude && (
              <div style={{ marginBottom: 12 }}>
                <strong>{t('reports.gpsLocation')}</strong>
                <p style={{ color: 'var(--muted)' }}>{detail.latitude.toFixed(6)}, {detail.longitude.toFixed(6)}</p>
              </div>
            )}
            {detail.address_text && (
              <div style={{ marginBottom: 12 }}>
                <strong>{t('reports.address')}</strong>
                <p style={{ color: 'var(--muted)' }}>{detail.address_text}</p>
              </div>
            )}
            {detail.evidence && detail.evidence.length > 0 && (
              <div style={{ marginBottom: 12 }}>
                <strong>{t('reports.evidence')}</strong>
                {detail.evidence.map((e, i) => (
                  <div key={i} style={{ padding: '4px 0', color: 'var(--muted)', fontSize: 13 }}>
                    {e.type}: {e.value}
                  </div>
                ))}
              </div>
            )}
            {['pending', 'under_review', 'verified'].includes(detail.status) && (
              <div style={{ marginBottom: 12 }}>
                <strong>Investigation notes</strong>
                <textarea rows={2} placeholder="Findings, evidence, follow-up actions…" value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  style={{ width: '100%', marginTop: 6 }} />
              </div>
            )}
            {history.length > 0 && (
              <div style={{ marginBottom: 12 }}>
                <strong>Status history</strong>
                <div style={{ marginTop: 6 }}>
                  {history.map((h) => (
                    <div key={h.id} style={{ padding: '4px 0', borderBottom: '1px solid rgba(255,255,255,.06)', fontSize: 13 }}>
                      <span className={`badge ${badge(h.status)}`}>{h.status}</span>
                      <span style={{ color: 'var(--muted)', marginLeft: 8 }}>{new Date(h.created_at).toLocaleString()} · {h.changed_by_name || 'system'}</span>
                      {h.notes && <div style={{ color: 'var(--muted)', marginTop: 2 }}>{h.notes}</div>}
                    </div>
                  ))}
                </div>
              </div>
            )}
            <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
              {detail.status === 'pending' && <button className="btn" onClick={async () => { await setStatusNow(detail.id, 'under_review', notes); setDetail(null); }}>{t('reports.review')}</button>}
              {detail.status === 'under_review' && <button className="btn" onClick={async () => { await setStatusNow(detail.id, 'verified', notes); setDetail(null); }}>{t('reports.verify')}</button>}
              {detail.status === 'verified' && <button className="btn" onClick={async () => { await setStatusNow(detail.id, 'resolved', notes); setDetail(null); }}>{t('reports.resolve')}</button>}
              {['pending', 'under_review', 'verified'].includes(detail.status) && (
                <button className="btn danger" onClick={async () => { await setStatusNow(detail.id, 'rejected', notes); setDetail(null); }}>{t('reports.reject')}</button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
