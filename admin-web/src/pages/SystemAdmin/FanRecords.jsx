import { useEffect, useState } from 'react';
import { api } from '../../api/client';

export default function FanRecords() {
  const [records, setRecords] = useState([]);
  const [form, setForm] = useState({ full_name: '', phone: '', fan_number: '' });
  const [message, setMessage] = useState({ type: '', text: '' });
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [saving, setSaving] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const data = await api.get('/admin/fan-records');
      if (!Array.isArray(data)) {
        throw new Error('The server returned an unexpected records response.');
      }
      setRecords(data);
      setLoadError(false);
      setMessage((current) =>
        current.text.startsWith('Could not load FAN records:')
          ? { type: '', text: '' }
          : current,
      );
    } catch (error) {
      setLoadError(true);
      setMessage({ type: 'err', text: `Could not load FAN records: ${error.message}` });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const submit = async (event) => {
    event.preventDefault();
    if (saving) return;

    setSaving(true);
    setMessage({ type: 'info', text: 'Saving mock ID record…' });
    try {
      const record = await api.post('/admin/fan-records', form);
      if (!record?.id) {
        throw new Error('The server did not confirm the save. Check the records list before retrying.');
      }
      setRecords((current) => [record, ...current.filter((item) => item.id !== record.id)]);
      setLoadError(false);
      setForm({ full_name: '', phone: '', fan_number: '' });
      setMessage({
        type: 'ok',
        text: `Saved: ${record.full_name} (${record.fan_number}). The record is shown below.`,
      });
    } catch (error) {
      let text = `Save failed: ${error.message}`;
      if (error.status >= 500) {
        text = 'The server could not save this record. Its FAN database migration may be missing; ask the system administrator to check the backend deployment.';
      } else if (error.status === 422 && /12-digit/i.test(error.message)) {
        text = 'The backend is still using the old 12-digit FAN rule. Deploy the updated backend and migration, then try again.';
      } else if (error.status === 403) {
        text = 'Only a System Admin can add FAN mock records.';
      }
      setMessage({ type: 'err', text });
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (record) => {
    try {
      await api.patch(`/admin/fan-records/${record.id}`, {
        is_active: !record.is_active,
      });
      await load();
    } catch (error) {
      setMessage({ type: 'err', text: error.message });
    }
  };

  return (
    <div className="panel" style={{ marginTop: 16 }}>
      <h2>FAN identity verification records</h2>
      <p className="muted">
        Add mock identity details from the original ID. Citizens are verified
        only when the 16-digit FAN matches an active record; the app displays
        these saved details, not the QR contents.
      </p>
      {message.text && (
        <div
          className={`msg ${message.type}`}
          role={message.type === 'err' ? 'alert' : 'status'}
          aria-live="polite"
        >
          {message.text}
        </div>
      )}
      <form onSubmit={submit}>
        <div className="form-row">
          <label>
            Full name on mock record
            <input
              value={form.full_name}
              onChange={(event) => setForm({ ...form, full_name: event.target.value })}
              maxLength={150}
              autoComplete="name"
              disabled={saving}
              required
            />
          </label>
          <label>
            Phone number on mock record
            <input
              value={form.phone}
              onChange={(event) => setForm({ ...form, phone: event.target.value })}
              maxLength={32}
              autoComplete="tel"
              disabled={saving}
              required
            />
          </label>
          <label>
            FAN number (16 digits)
            <input
              value={form.fan_number}
              onChange={(event) => setForm({ ...form, fan_number: event.target.value.replace(/\D/g, '').slice(0, 16) })}
              inputMode="numeric"
              maxLength={16}
              pattern="[0-9]{16}"
              placeholder="16 digits"
              disabled={saving}
              required
            />
          </label>
        </div>
        <button className="btn" type="submit" disabled={saving}>
          {saving ? 'Saving…' : 'Add mock ID record'}
        </button>
      </form>

      <button
        className="btn small ghost"
        type="button"
        onClick={load}
        disabled={loading}
        style={{ marginTop: 16 }}
      >
        {loading ? 'Loading records…' : 'Refresh records'}
      </button>

      <div style={{ overflowX: 'auto', marginTop: 20 }}>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Phone</th>
              <th>FAN number</th>
              <th>Use</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {records.map((record) => (
              <tr key={record.id}>
                <td>{record.full_name || '—'}</td>
                <td>{record.phone || '—'}</td>
                <td>{record.fan_number}</td>
                <td>{record.verified_user_id ? 'Used' : 'Available'}</td>
                <td>
                  <span className={`badge ${record.is_active ? 'green' : 'blue'}`}>
                    {record.is_active ? 'Active' : 'Inactive'}
                  </span>
                </td>
                <td>
                  <button className="btn small ghost" onClick={() => toggle(record)}>
                    {record.is_active ? 'Deactivate' : 'Activate'}
                  </button>
                </td>
              </tr>
            ))}
            {!loading && !loadError && records.length === 0 && (
              <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>No mock ID records yet.</td></tr>
            )}
            {!loading && loadError && (
              <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>Records could not be loaded. Check the message above and refresh after the server issue is fixed.</td></tr>
            )}
            {loading && (
              <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>Loading records…</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
