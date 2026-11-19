/**
 * System Configuration Management — read/edit the platform-wide settings
 * stored in the system_config table (spec §5). Backed by GET /api/config and
 * PUT /api/config/:key (now writes real audit_log rows — see backend
 * config.controller.js).
 */
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../../api/client';

export default function ConfigPage() {
  const { t } = useTranslation();
  const [settings, setSettings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [newKey, setNewKey] = useState('');
  const [newValue, setNewValue] = useState('');
  const [editing, setEditing] = useState(null);
  const [editValue, setEditValue] = useState('');

  const load = async () => {
    setLoading(true);
    try {
      const data = await api.get('/config');
      const rows = data?.settings || [];
      setSettings(rows);
    } catch (e) { setMsg({ type: 'err', text: e.message }); }
    finally { setLoading(false); }
  };
  useEffect(() => { load(); }, []);

  const add = async (e) => {
    e.preventDefault();
    if (!newKey.trim()) return;
    try {
      await api.put(`/config/${encodeURIComponent(newKey.trim())}`, { value: newValue });
      setMsg({ type: 'ok', text: `Setting "${newKey}" added.` });
      setNewKey(''); setNewValue('');
      load();
    } catch (e) { setMsg({ type: 'err', text: e.message }); }
  };

  const save = async (e) => {
    e.preventDefault();
    try {
      await api.put(`/config/${encodeURIComponent(editing.setting_name)}`, { value: editValue });
      setMsg({ type: 'ok', text: `Setting "${editing.setting_name}" updated.` });
      setEditing(null);
      load();
    } catch (e) { setMsg({ type: 'err', text: e.message }); }
  };

  const remove = async (s) => {
    // system_config has no DELETE endpoint, but we can null it via an update.
    // (Spec §5 — configuration changes must be recorded in audit log.)
    if (!window.confirm(`Clear the value of "${s.setting_name}"? The audit log will record this change.`)) return;
    try {
      await api.put(`/config/${encodeURIComponent(s.setting_name)}`, { value: '' });
      setMsg({ type: 'ok', text: `"${s.setting_name}" cleared.` });
      load();
    } catch (e) { setMsg({ type: 'err', text: e.message }); }
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('systemAdmin.config.title', { defaultValue: 'System Configuration' })}</h1>
          <p>{t('systemAdmin.config.subtitle', { defaultValue: 'Platform-wide operational settings and parameters' })}</p>
        </div>
        <button className="btn ghost" onClick={load}>↻ Refresh</button>
      </div>

      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel" style={{ marginBottom: 16 }}>
        <h2>{t('systemAdmin.config.addSetting', { defaultValue: 'Add / Update Setting' })}</h2>
        <form onSubmit={add}>
          <div className="form-row">
            <label>{t('systemAdmin.config.key', { defaultValue: 'Setting key' })}
              <input value={newKey} onChange={(e) => setNewKey(e.target.value)} placeholder="e.g. report_max_attachment_mb" required />
            </label>
            <label>{t('systemAdmin.config.value', { defaultValue: 'Value' })}
              <input value={newValue} onChange={(e) => setNewValue(e.target.value)} placeholder="string, number, or JSON" required />
            </label>
          </div>
          <button className="btn">{t('systemAdmin.config.save', { defaultValue: 'Save setting' })}</button>
        </form>
      </div>

      <div className="panel">
        <h2>{t('systemAdmin.config.currentSettings', { defaultValue: 'Current Settings' })}</h2>
        {loading && <p style={{ color: 'var(--muted)' }}>Loading…</p>}
        {!loading && settings.length === 0 && <p style={{ color: 'var(--muted)' }}>{t('systemAdmin.config.noSettings', { defaultValue: 'No settings defined yet.' })}</p>}
        <table>
          <thead><tr><th>Key</th><th>Value</th><th>Last modified</th><th>Actions</th></tr></thead>
          <tbody>
            {settings.map(s => (
              <tr key={s.id}>
                <td style={{ fontFamily: 'monospace', fontSize: 13 }}>{s.setting_name}</td>
                <td style={{ fontFamily: 'monospace', fontSize: 13, maxWidth: 400, overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.setting_value}</td>
                <td style={{ color: 'var(--muted)', fontSize: 12 }}>{s.last_modified ? new Date(s.last_modified).toLocaleString() : '—'}</td>
                <td>
                  <button className="btn small ghost" onClick={() => { setEditing(s); setEditValue(s.setting_value); }}>Edit</button>
                  <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => remove(s)}>Clear</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editing && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 60, display: 'grid', placeItems: 'center' }} onClick={() => setEditing(null)}>
          <div className="panel" style={{ maxWidth: 480, width: '90%' }} onClick={(e) => e.stopPropagation()}>
            <h2 style={{ marginTop: 0 }}>Edit {editing.setting_name}</h2>
            <form onSubmit={save}>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13 }}>
                Value
                <textarea value={editValue} onChange={(e) => setEditValue(e.target.value)} rows={4} style={{ fontFamily: 'monospace' }} required />
              </label>
              <div className="form-actions" style={{ marginTop: 12 }}>
                <button className="btn">Save</button>
                <button type="button" className="btn ghost" onClick={() => setEditing(null)}>Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
