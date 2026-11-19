/**
 * System Admin Profile & Account Settings — the logged-in admin's own
 * profile, recent account activity, and a change-password form (spec §11).
 * Backed by GET /api/auth/me, PUT /api/auth/me, PUT /api/auth/change-password
 * — password changes now write audit_log rows (see auth.controller.js).
 */
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../context/AuthContext';
import { api } from '../../api/client';

export default function ProfilePage() {
  const { t } = useTranslation();
  const { user, updateUser, logout } = useAuth();
  const [form, setForm] = useState({ full_name: '', phone: '', email: '', region: '', sub_city: '', woreda: '' });
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [pwForm, setPwForm] = useState({ currentPassword: '', newPassword: '', confirm: '' });
  const [pwSaving, setPwSaving] = useState(false);
  const [pwMsg, setPwMsg] = useState({ type: '', text: '' });
  const [recent, setRecent] = useState([]);

  useEffect(() => {
    if (user) {
      setForm({
        full_name: user.full_name || '',
        phone: user.phone || '',
        email: user.email || '',
        region: user.region || '',
        sub_city: user.sub_city || '',
        woreda: user.woreda || '',
      });
    }
  }, [user]);

  useEffect(() => {
    api.get('/admin/audit?limit=8&user_id=' + (user?.id || ''))
      .then(d => setRecent(d?.items || []))
      .catch(() => {});
  }, [user?.id]);

  const saveProfile = async (e) => {
    e.preventDefault();
    setSaving(true);
    setMsg({ type: '', text: '' });
    try {
      const data = await api.put('/auth/me', {
        full_name: form.full_name.trim(),
        phone: form.phone.trim(),
        email: form.email.trim(),
        region: form.region,
        sub_city: form.sub_city,
        woreda: form.woreda,
      });
      updateUser(data);
      setMsg({ type: 'ok', text: 'Profile updated.' });
    } catch (e) { setMsg({ type: 'err', text: e.message }); }
    finally { setSaving(false); }
  };

  const changePassword = async (e) => {
    e.preventDefault();
    setPwMsg({ type: '', text: '' });
    if (pwForm.newPassword !== pwForm.confirm) {
      setPwMsg({ type: 'err', text: 'New password and confirmation do not match.' });
      return;
    }
    if (pwForm.newPassword.length < 6) {
      setPwMsg({ type: 'err', text: 'New password must be at least 6 characters.' });
      return;
    }
    setPwSaving(true);
    try {
      await api.put('/auth/change-password', {
        currentPassword: pwForm.currentPassword,
        newPassword: pwForm.newPassword,
      });
      setPwMsg({ type: 'ok', text: 'Password changed. The change has been recorded in the audit log.' });
      setPwForm({ currentPassword: '', newPassword: '', confirm: '' });
    } catch (e) { setPwMsg({ type: 'err', text: e.message }); }
    finally { setPwSaving(false); }
  };

  if (!user) return null;

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('systemAdmin.profile.title', { defaultValue: 'My Profile' })}</h1>
          <p>{t('systemAdmin.profile.subtitle', { defaultValue: 'Manage your System Admin account and security settings' })}</p>
        </div>
      </div>

      <div className="grid-2">
        {/* Profile card */}
        <div className="panel">
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 18 }}>
            <div className="avatar" style={{ width: 56, height: 56, fontSize: 22 }}>{user.full_name?.[0]}</div>
            <div>
              <h2 style={{ margin: 0 }}>{user.full_name}</h2>
              <span className="badge blue" style={{ marginTop: 4 }}>{user.role}</span>
            </div>
          </div>

          <form onSubmit={saveProfile}>
            <div className="form-row">
              <label>Full name
                <input value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required />
              </label>
              <label>Phone
                <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} required />
              </label>
              <label>Email
                <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
              </label>
              <label>Region
                <input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} />
              </label>
              <label>Sub-city
                <input value={form.sub_city} onChange={(e) => setForm({ ...form, sub_city: e.target.value })} />
              </label>
              <label>Woreda
                <input value={form.woreda} onChange={(e) => setForm({ ...form, woreda: e.target.value })} />
              </label>
            </div>
            {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}
            <button className="btn" disabled={saving}>{saving ? 'Saving…' : 'Save profile'}</button>
          </form>
        </div>

        {/* Change password */}
        <div className="panel">
          <h2>{t('systemAdmin.profile.changePassword', { defaultValue: 'Change Password' })}</h2>
          <p style={{ color: 'var(--muted)', fontSize: 13 }}>
            {t('systemAdmin.profile.passwordNote', { defaultValue: 'Your current password is required. Every password change is recorded in the audit log.' })}
          </p>
          <form onSubmit={changePassword}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13, marginBottom: 12 }}>
              Current password
              <input type="password" value={pwForm.currentPassword} onChange={(e) => setPwForm({ ...pwForm, currentPassword: e.target.value })} required autoComplete="current-password" />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13, marginBottom: 12 }}>
              New password
              <input type="password" value={pwForm.newPassword} onChange={(e) => setPwForm({ ...pwForm, newPassword: e.target.value })} required autoComplete="new-password" />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13, marginBottom: 12 }}>
              Confirm new password
              <input type="password" value={pwForm.confirm} onChange={(e) => setPwForm({ ...pwForm, confirm: e.target.value })} required autoComplete="new-password" />
            </label>
            {pwMsg.text && <div className={`msg ${pwMsg.type}`}>{pwMsg.text}</div>}
            <button className="btn" disabled={pwSaving}>{pwSaving ? 'Saving…' : 'Change password'}</button>
          </form>
        </div>
      </div>

      {/* Recent account activity */}
      <div className="panel" style={{ marginTop: 16 }}>
        <h2>{t('systemAdmin.profile.recentActivity', { defaultValue: 'My Recent Activity' })}</h2>
        {recent.length === 0 && <p style={{ color: 'var(--muted)' }}>No recent activity.</p>}
        {recent.length > 0 && (
          <table>
            <thead><tr><th style={{ textAlign: 'left' }}>When</th><th style={{ textAlign: 'left' }}>Action</th><th style={{ textAlign: 'left' }}>Entity</th><th style={{ textAlign: 'left' }}>IP</th></tr></thead>
            <tbody>
              {recent.map(a => (
                <tr key={a.id}>
                  <td style={{ color: 'var(--muted)', fontFamily: 'monospace', fontSize: 11 }}>{a.created_at ? new Date(a.created_at).toLocaleString() : '—'}</td>
                  <td><span className="badge blue">{a.action.replace(/_/g, ' ')}</span></td>
                  <td style={{ color: 'var(--muted)' }}>{a.entity || '—'}</td>
                  <td style={{ fontFamily: 'monospace', fontSize: 11 }}>{a.ip_address || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <button className="btn ghost" style={{ marginTop: 12 }} onClick={logout}>Log out securely</button>
      </div>
    </div>
  );
}
