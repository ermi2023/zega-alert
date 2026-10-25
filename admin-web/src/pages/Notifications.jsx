import { useState, useEffect, useCallback } from 'react';
import { api } from '../api/client';

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);
  const [form, setForm] = useState({ title: '', body: '', delivery_type: 'push' });
  const [success, setSuccess] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.get('/notifications?limit=50');
      setNotifications(Array.isArray(data) ? data : data?.notifications ?? []);
    } catch (e) {
      setError(e.message || 'Failed to load notifications');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const markAllRead = async () => {
    try {
      await api.patch('/notifications/read-all', {});
      load();
    } catch (e) { setError(e.message); }
  };

  const markRead = async (id) => {
    try {
      await api.patch(`/notifications/${id}/read`, {});
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, is_read: true } : n));
    } catch (e) { setError(e.message); }
  };

  const send = async (e) => {
    e.preventDefault();
    if (!form.title.trim() || !form.body.trim()) return;
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      await api.post('/notifications', {
        title: form.title,
        body: form.body,
        delivery_type: form.delivery_type,
      });
      setSuccess('Notification broadcast sent successfully.');
      setForm({ title: '', body: '', delivery_type: 'push' });
      load();
    } catch (e) {
      setError(e.message || 'Failed to send notification');
    } finally {
      setSending(false);
    }
  };

  const unreadCount = notifications.filter(n => !n.is_read).length;

  return (
    <div className="page-container">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ margin: 0 }}>Notifications</h1>
          {unreadCount > 0 && (
            <span style={{ background: '#ef4444', color: '#fff', borderRadius: 12, padding: '2px 10px', fontSize: 12, fontWeight: 700, marginTop: 4, display: 'inline-block' }}>
              {unreadCount} unread
            </span>
          )}
        </div>
        {unreadCount > 0 && (
          <button className="btn" onClick={markAllRead}>Mark all read</button>
        )}
      </div>

      {/* Broadcast form */}
      <div style={{ background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12, padding: 20, marginBottom: 28 }}>
        <h3 style={{ marginTop: 0, marginBottom: 16 }}>📢 Broadcast Notification</h3>
        <form onSubmit={send} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 12 }}>
            <div>
              <label style={{ display: 'block', fontWeight: 600, marginBottom: 4, fontSize: 13 }}>Title *</label>
              <input
                className="input"
                value={form.title}
                onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
                placeholder="Alert headline / notification title"
                required
              />
            </div>
            <div>
              <label style={{ display: 'block', fontWeight: 600, marginBottom: 4, fontSize: 13 }}>Delivery Channel</label>
              <select className="input" value={form.delivery_type} onChange={e => setForm(f => ({ ...f, delivery_type: e.target.value }))}>
                <option value="push">Push Notification</option>
                <option value="sms">SMS</option>
                <option value="broadcast">Regional Broadcast</option>
              </select>
            </div>
          </div>
          <div>
            <label style={{ display: 'block', fontWeight: 600, marginBottom: 4, fontSize: 13 }}>Body *</label>
            <textarea
              className="input"
              rows={3}
              value={form.body}
              onChange={e => setForm(f => ({ ...f, body: e.target.value }))}
              placeholder="Detailed emergency warning or safety notice"
              required
              style={{ resize: 'vertical', fontFamily: 'inherit' }}
            />
          </div>
          {error && <div style={{ color: '#ef4444', fontSize: 13 }}>{error}</div>}
          {success && <div style={{ color: '#22c55e', fontSize: 13 }}>{success}</div>}
          <div>
            <button className="btn" type="submit" disabled={sending} style={{ minWidth: 160 }}>
              {sending ? 'Sending Broadcast...' : 'Send Broadcast'}
            </button>
          </div>
        </form>
      </div>

      {/* Notification list */}
      <h3 style={{ marginBottom: 12 }}>Recent Notifications</h3>
      {loading ? (
        <div style={{ textAlign: 'center', padding: 40 }}>Loading notifications...</div>
      ) : notifications.length === 0 ? (
        <div style={{ textAlign: 'center', padding: 40, color: 'var(--muted)' }}>No notifications found.</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {notifications.map(n => (
            <div
              key={n.id}
              style={{
                background: n.is_read ? 'var(--card)' : 'var(--accent-soft, rgba(59,130,246,0.08))',
                border: `1px solid ${n.is_read ? 'var(--border)' : 'var(--accent, #3b82f6)'}`,
                borderRadius: 10,
                padding: '12px 16px',
                display: 'flex',
                alignItems: 'flex-start',
                gap: 12,
              }}
            >
              <span style={{ fontSize: 20, flexShrink: 0, marginTop: 2 }}>
                {n.delivery_type === 'sms' ? '💬' : '🔔'}
              </span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: n.is_read ? 600 : 700, fontSize: 14 }}>{n.title}</div>
                <div style={{ color: 'var(--muted)', fontSize: 13, marginTop: 2 }}>{n.body}</div>
                <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 6 }}>
                  {n.created_at ? new Date(n.created_at).toLocaleString() : ''}
                  {n.delivery_type ? ` · ${n.delivery_type.toUpperCase()}` : ''}
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
                {!n.is_read ? (
                  <button
                    className="btn ghost"
                    style={{ fontSize: 12, padding: '4px 10px' }}
                    onClick={() => markRead(n.id)}
                  >
                    Mark read
                  </button>
                ) : (
                  <span style={{ fontSize: 12, color: 'var(--muted)' }}>✓ Read</span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
