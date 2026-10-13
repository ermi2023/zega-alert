import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

export default function Audit() {
  const { t } = useTranslation();
  const [data, setData] = useState({ items: [], total: 0, page: 1, totalPages: 0 });
  const [loading, setLoading] = useState(false);
  const [filters, setFilters] = useState({
    q: '',
    action: '',
    entity: '',
    from: '',
    to: '',
    page: 1,
    limit: 25,
  });

  const load = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (filters.q) params.append('q', filters.q);
      if (filters.action) params.append('action', filters.action);
      if (filters.entity) params.append('entity', filters.entity);
      if (filters.from) params.append('from', filters.from);
      if (filters.to) params.append('to', filters.to);
      params.append('page', filters.page);
      params.append('limit', filters.limit);
      const result = await api.get(`/admin/audit?${params.toString()}`);
      setData(result);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [filters.page]);

  const search = () => {
    setFilters({ ...filters, page: 1 });
    // Use timeout to ensure state is updated
    setTimeout(load, 0);
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') search();
  };

  const setPage = (p) => setFilters({ ...filters, page: p });

  const exportCsv = () => {
    const headers = ['Time', 'User', 'Action', 'Entity', 'Entity ID', 'Detail'];
    const rows = data.items.map(a => [
      new Date(a.created_at).toISOString(),
      a.full_name || a.user_id || 'system',
      a.action,
      a.entity || '',
      a.entity_id || '',
      JSON.stringify(a.detail || ''),
    ]);
    const csv = [headers, ...rows].map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit_log_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Get unique actions and entities for dropdown filters
  const [actions, setActions] = useState([]);
  const [entities, setEntities] = useState([]);

  useEffect(() => {
    // Load distinct actions and entities for filter dropdowns
    api.get('/admin/audit?limit=500').then(d => {
      const actionSet = new Set();
      const entitySet = new Set();
      (d.items || []).forEach(a => {
        if (a.action) actionSet.add(a.action);
        if (a.entity) entitySet.add(a.entity);
      });
      setActions([...actionSet].sort());
      setEntities([...entitySet].sort());
    }).catch(() => {});
  }, []);

  const badge = (v) => {
    if (!v) return 'gray';
    if (v.includes('create')) return 'green';
    if (v.includes('update') || v.includes('edit')) return 'blue';
    if (v.includes('delete')) return 'red';
    if (v.includes('login')) return 'amber';
    if (v.includes('dispatch')) return 'purple';
    return 'gray';
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('audit.title')}</h1>
          <p>{t('audit.subtitle')} · {data.total} total entries</p>
        </div>
        <div className="filters">
          <button className="btn ghost" onClick={exportCsv}>{t('audit.exportCsv')}</button>
          <button className="btn" onClick={search}>{t('audit.search')}</button>
        </div>
      </div>

      {/* Filters */}
      <div className="panel" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <label style={{ flex: 1, minWidth: 150 }}>
            {t('audit.search')}
            <input
              value={filters.q}
              onChange={(e) => setFilters({ ...filters, q: e.target.value })}
              onKeyDown={handleKeyDown}
              placeholder={t('audit.searchPlaceholder')}
            />
          </label>
          <label style={{ minWidth: 150 }}>
            {t('audit.action')}
            <select value={filters.action} onChange={(e) => setFilters({ ...filters, action: e.target.value })}>
              <option value="">{t('audit.allActions')}</option>
              {actions.map(a => <option key={a} value={a}>{a}</option>)}
            </select>
          </label>
          <label style={{ minWidth: 150 }}>
            {t('audit.entity')}
            <select value={filters.entity} onChange={(e) => setFilters({ ...filters, entity: e.target.value })}>
              <option value="">{t('audit.allEntities')}</option>
              {entities.map(ent => <option key={ent} value={ent}>{ent}</option>)}
            </select>
          </label>
          <label>
            From
            <input type="date" value={filters.from} onChange={(e) => setFilters({ ...filters, from: e.target.value })} />
          </label>
          <label>
            To
            <input type="date" value={filters.to} onChange={(e) => setFilters({ ...filters, to: e.target.value })} />
          </label>
        </div>
      </div>

      {/* Table */}
      <div className="panel">
        {loading ? (
          <p style={{ color: 'var(--muted)', padding: 24, textAlign: 'center' }}>{t('loading')}</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>{t('audit.time')}</th>
                <th>{t('audit.user')}</th>
                <th>{t('audit.action')}</th>
                <th>{t('audit.entity')}</th>
                <th>{t('audit.entityId')}</th>
                <th>{t('audit.detail')}</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map(a => (
                <tr key={a.id}>
                  <td style={{ whiteSpace: 'nowrap' }}>{new Date(a.created_at).toLocaleString()}</td>
                  <td>{a.full_name || <span style={{ color: 'var(--muted)' }}>system</span>}</td>
                  <td><span className={`badge ${badge(a.action)}`}>{a.action}</span></td>
                  <td>{a.entity || '—'}</td>
                  <td style={{ color: 'var(--muted)', fontFamily: 'monospace', fontSize: 12 }}>{a.entity_id?.slice(0, 8) || '—'}</td>
                  <td style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {a.detail && typeof a.detail === 'object' ? JSON.stringify(a.detail).slice(0, 60) : '—'}
                  </td>
                </tr>
              ))}
              {data.items.length === 0 && (
                <tr><td colSpan={6} style={{ color: 'var(--muted)', padding: 24, textAlign: 'center' }}>{t('audit.noEntries')}</td></tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      {data.totalPages > 1 && (
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, marginTop: 16 }}>
          <button className="btn small ghost" disabled={filters.page <= 1} onClick={() => setPage(filters.page - 1)}>
            {t('audit.previous')}
          </button>
          <span style={{ color: 'var(--muted)', fontSize: 13 }}>
            {t('audit.pageInfo', { current: data.page, total: data.totalPages, count: data.total })}
          </span>
          <button className="btn small ghost" disabled={filters.page >= data.totalPages} onClick={() => setPage(filters.page + 1)}>
            {t('audit.next')}
          </button>
        </div>
      )}
    </div>
  );
}
