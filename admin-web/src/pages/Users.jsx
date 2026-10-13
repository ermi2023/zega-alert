import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

const ROLES = ['citizen', 'police', 'dispatcher', 'regional_admin', 'system_admin'];

export default function Users() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [role, setRole] = useState('');
  const [q, setQ] = useState('');
  const [form, setForm] = useState({ full_name: '', phone: '', password: '', role: 'police', region: '' });
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [editing, setEditing] = useState(null);
  const [editForm, setEditForm] = useState({ full_name: '', role: 'citizen', region: '', sub_city: '' });

  const load = () => api.get(`/admin/users?role=${role}&q=${q}`).then(setRows);
  useEffect(() => { load(); }, [role, q]);

  const submit = async (e) => {
    e.preventDefault();
    try {
      await api.post('/admin/users', form);
      setMsg({ type: 'ok', text: 'User created (password: ' + form.password + ')' });
      setForm({ full_name: '', phone: '', password: '', role: 'police', region: '' });
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const toggle = async (id, active) => {
    try {
      await api.patch(`/admin/users/${id}`, { is_active: active });
      load();
    } catch (ex) {
      if (ex.status === 409 && window.confirm(ex.message + '\n\nSuspend anyway?')) {
        await api.patch(`/admin/users/${id}`, { is_active: active, confirm_active_cases: true });
        load();
      } else { setMsg({ type: 'err', text: ex.message }); }
    }
  };

  const startEdit = (u) => {
    setEditing(u);
    setEditForm({ full_name: u.full_name, role: u.role, region: u.region || '', sub_city: u.sub_city || '' });
  };

  const saveEdit = async (e) => {
    e.preventDefault();
    try {
      await api.patch(`/admin/users/${editing.id}`, editForm);
      setMsg({ type: 'ok', text: `Updated ${editForm.full_name}.` });
      setEditing(null);
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
  };

  const remove = async (u) => {
    if (!window.confirm(`Delete user ${u.full_name}? This cannot be undone.`)) return;
    try {
      await api.del(`/admin/users/${u.id}`);
      setMsg({ type: 'ok', text: `${u.full_name} deleted.` });
      load();
    } catch (ex) {
      if (ex.status === 409 && window.confirm(ex.message + '\n\nDelete anyway?')) {
        try {
          await api.del(`/admin/users/${u.id}`, { confirm_active_cases: true });
          setMsg({ type: 'ok', text: `${u.full_name} deleted.` });
          load();
        } catch (ex2) { setMsg({ type: 'err', text: ex2.message }); }
      } else { setMsg({ type: 'err', text: ex.message }); }
    }
  };

  return (
    <div>
      <div className="page-head"><div><h1>{t('users.title')}</h1><p>{t('users.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <div className="panel">
        <h2>{t('users.createAccount')}</h2>
        <form onSubmit={submit}>
          <div className="form-row">
            <label>{t('users.fullName')}<input value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required /></label>
            <label>{t('users.phone')}<input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} required /></label>
            <label>{t('users.tempPassword')}<input value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} required /></label>
            <label>{t('users.role')}
              <select value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                {ROLES.map((r) => <option key={r}>{r}</option>)}
              </select>
            </label>
            <label>{t('users.region')}<input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} /></label>
          </div>
          <button className="btn">{t('users.createUser')}</button>
        </form>
      </div>

      <div className="filters">
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="">{t('users.allRoles')}</option>
          {ROLES.map((r) => <option key={r}>{r}</option>)}
        </select>
        <input placeholder="Search name/phone…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>

      <div className="panel">
        <table>
          <thead><tr><th>{t('users.name')}</th><th>Phone</th><th>Role</th><th>Region</th><th>{t('users.status')}</th><th>{t('users.action')}</th></tr></thead>
          <tbody>
            {rows.map((u) => (
              <tr key={u.id}>
                <td>{u.full_name}</td><td>{u.phone}</td>
                <td><span className="badge blue">{u.role}</span></td>
                <td>{u.region || '—'}</td>
                <td>{u.is_active ? <span className="badge green">{t('users.active')}</span> : <span className="badge red">{t('users.disabled')}</span>}</td>
                <td>
                  <button className="btn small ghost" onClick={() => startEdit(u)}>Edit</button>
                  {u.is_active
                    ? <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => toggle(u.id, false)}>{t('users.disable')}</button>
                    : <button className="btn small" style={{ marginLeft: 4 }} onClick={() => toggle(u.id, true)}>{t('users.enable')}</button>}
                  <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => remove(u)}>Delete</button>
                </td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('users.noUsers')}</td></tr>}
          </tbody>
        </table>
      </div>

      {editing && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 60, display: 'grid', placeItems: 'center' }}
          onClick={() => setEditing(null)}>
          <div className="panel" style={{ maxWidth: 460, width: '90%' }} onClick={(e) => e.stopPropagation()}>
            <h2 style={{ marginTop: 0 }}>Edit {editing.full_name}</h2>
            <form onSubmit={saveEdit}>
              <div className="form-row">
                <label>{t('users.fullName')}<input value={editForm.full_name} onChange={(e) => setEditForm({ ...editForm, full_name: e.target.value })} required /></label>
                <label>{t('users.role')}
                  <select value={editForm.role} onChange={(e) => setEditForm({ ...editForm, role: e.target.value })}>
                    {ROLES.map((r) => <option key={r}>{r}</option>)}
                  </select>
                </label>
                <label>{t('users.region')}<input value={editForm.region} onChange={(e) => setEditForm({ ...editForm, region: e.target.value })} /></label>
                <label>Sub-city<input value={editForm.sub_city} onChange={(e) => setEditForm({ ...editForm, sub_city: e.target.value })} /></label>
              </div>
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
