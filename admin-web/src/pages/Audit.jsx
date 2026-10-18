import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

export default function Audit() {
  const { t } = useTranslation();
  const [data, setData] = useState({ items: [], total: 0, page: 1, totalPages: 0 });
  const [loading, setLoading] = useState(false);
  const [showExport, setShowExport] = useState(false);
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

  useEffect(() => {
    const close = (e) => {
      if (!e.target.closest || !e.target.closest('.filters')) setShowExport(false);
    };
    document.addEventListener('click', close);
    return () => document.removeEventListener('click', close);
  }, []);

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
    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit_log_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const exportExcel = () => {
    const headers = ['Time', 'User', 'Action', 'Entity', 'Entity ID', 'Detail'];
    const rows = data.items.map(a => [
      new Date(a.created_at).toISOString(),
      a.full_name || a.user_id || 'system',
      a.action,
      a.entity || '',
      a.entity_id || '',
      JSON.stringify(a.detail || ''),
    ]);
    // XML Spreadsheet 2003 format - opens natively in Excel.
    const esc = (v) => String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
  <Worksheet ss:Name="Audit Log">
    <Table>
      <Row>${headers.map(h => `<Cell><Data ss:Type="String">${esc(h)}</Data></Cell>`).join('')}</Row>
      ${rows.map(r => `<Row>${r.map(c => `<Cell><Data ss:Type="String">${esc(c)}</Data></Cell>`).join('')}</Row>`).join('\n      ')}
    </Table>
  </Worksheet>
</Workbook>`;
    const blob = new Blob([xml], { type: 'application/vnd.ms-excel' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit_log_${new Date().toISOString().slice(0, 10)}.xls`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const exportPdf = () => {
    const headers = ['Time', 'User', 'Action', 'Entity', 'Entity ID', 'Detail'];
    const rows = data.items.map(a => [
      new Date(a.created_at).toLocaleString(),
      a.full_name || a.user_id || 'system',
      a.action,
      a.entity || '',
      (a.entity_id || '').slice(0, 8),
      (a.detail && typeof a.detail === 'object' ? JSON.stringify(a.detail).slice(0, 60) : ''),
    ]);
    const win = window.open('', '_blank');
    if (!win) return;
    win.document.write(`<!DOCTYPE html><html><head><title>Audit Log</title>
<style>
  body { font-family: Arial, sans-serif; margin: 24px; color: #111; }
  h1 { font-size: 18px; margin-bottom: 4px; }
  p { font-size: 12px; color: #555; margin-bottom: 16px; }
  table { width: 100%; border-collapse: collapse; font-size: 11px; }
  th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: left; }
  th { background: #f2f2f2; font-weight: 700; }
  tr:nth-child(even) { background: #fafafa; }
  @media print { body { margin: 12px; } }
</style></head><body>
<h1>Audit Log Export</h1>
<p>Generated ${new Date().toLocaleString()} · ${data.total} entries</p>
<table>
  <thead><tr>${headers.map(h => `<th>${h}</th>`).join('')}</tr></thead>
  <tbody>${rows.map(r => `<tr>${r.map(c => `<td>${String(c).replace(/</g, '&lt;')}</td>`).join('')}</tr>`).join('')}</tbody>
</table>
</body></html>`);
    win.document.close();
    win.focus();
    setTimeout(() => { win.print(); }, 300);
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
          <div style={{ position: 'relative', display: 'inline-block' }}>
            <button className="btn ghost" onClick={() => setShowExport(v => !v)}>Export ▾</button>
            {showExport && (
              <div style={{
                position: 'absolute', top: '100%', right: 0, marginTop: 4,
                background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 8,
                boxShadow: 'var(--shadow-2)', zIndex: 100, minWidth: 140, overflow: 'hidden',
              }}>
                <button className="btn ghost" style={{ width: '100%', textAlign: 'left', borderRadius: 0, justifyContent: 'flex-start' }} onClick={() => { exportCsv(); setShowExport(false); }}>CSV</button>
                <button className="btn ghost" style={{ width: '100%', textAlign: 'left', borderRadius: 0, justifyContent: 'flex-start' }} onClick={() => { exportExcel(); setShowExport(false); }}>Excel (.xls)</button>
                <button className="btn ghost" style={{ width: '100%', textAlign: 'left', borderRadius: 0, justifyContent: 'flex-start' }} onClick={() => { exportPdf(); setShowExport(false); }}>PDF</button>
              </div>
            )}
          </div>
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
