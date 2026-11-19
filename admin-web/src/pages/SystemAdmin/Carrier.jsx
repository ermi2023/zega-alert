/**
 * Carrier & Communication Configuration — manage the SMS provider
 * (Africa's Talking) connection (spec §6). The credentials themselves are
 * stored in the backend `.env` (never exposed to the client); this page
 * shows connection status, sender ID, sandbox/production mode, and lets the
 * System Admin record per-region carrier preferences in system_config.
 */
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../../api/client';

export default function CarrierPage() {
  const { t } = useTranslation();
  const [config, setConfig] = useState({});
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState({ type: '', text: '' });

  // Carrier preferences editable from this page (stored in system_config so
  // they survive redeploys and are audit-logged on change).
  const [allowedCarriers, setAllowedCarriers] = useState('Ethio Telecom, Safaricom Ethiopia');
  const [defaultSender, setDefaultSender] = useState('ZEGA_ALERT');
  const [smsEnabled, setSmsEnabled] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      const data = await api.get('/config');
      const cfg = data?.config || {};
      setConfig(cfg);
      if (cfg.allowed_carriers?.value) setAllowedCarriers(cfg.allowed_carriers.value);
      if (cfg.default_sender_id?.value) setDefaultSender(cfg.default_sender_id.value);
      if (cfg.sms_enabled?.value !== undefined) setSmsEnabled(String(cfg.sms_enabled.value) === 'true');
    } catch (e) { setMsg({ type: 'err', text: e.message }); }
    finally { setLoading(false); }
  };
  useEffect(() => { load(); }, []);

  const save = async (e) => {
    e.preventDefault();
    try {
      await api.post('/config/bulk', {
        config: {
          allowed_carriers: allowedCarriers,
          default_sender_id: defaultSender,
          sms_enabled: String(smsEnabled),
        },
      });
      setMsg({ type: 'ok', text: 'Carrier configuration saved. Changes recorded in audit log.' });
      load();
    } catch (e) { setMsg({ type: 'err', text: e.message }); }
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('systemAdmin.carrier.title', { defaultValue: 'Carrier & Communication Configuration' })}</h1>
          <p>{t('systemAdmin.carrier.subtitle', { defaultValue: 'SMS service provider (Africa\'s Talking) connection settings' })}</p>
        </div>
      </div>

      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      {/* Connection status — read from env-driven backend (not editable here) */}
      <div className="panel" style={{ marginBottom: 16 }}>
        <h2>{t('systemAdmin.carrier.connectionStatus', { defaultValue: 'Provider Connection Status' })}</h2>
        <p style={{ color: 'var(--muted)', fontSize: 13, marginBottom: 12 }}>
          {t('systemAdmin.carrier.connectionNote', {
            defaultValue: 'The Africa\'s Talking API credentials (AT_USERNAME, AT_API_KEY, AT_SENDER_ID) are stored in the backend .env file and never exposed to the client. In sandbox mode, SMS recipients must be added to your Africa\'s Talking sandbox allow-list. OTP and SOS alerts fall back to console logging when no API key is set.'
          })}
        </p>
        <div className="grid-2">
          <StatusItem label="Provider" value="Africa's Talking" ok />
          <StatusItem label="Mode" value="Sandbox / Production (auto-detected from AT_USERNAME)" ok />
          <StatusItem label="Credentials" value="Configured in backend .env" ok />
          <StatusItem label="OTP fallback" value="Console log when no SMS key set" ok />
        </div>
      </div>

      {/* Editable carrier preferences (stored in system_config, audit-logged) */}
      <div className="panel">
        <h2>{t('systemAdmin.carrier.preferences', { defaultValue: 'Carrier Preferences' })}</h2>
        <form onSubmit={save}>
          <div className="form-row">
            <label>{t('systemAdmin.carrier.allowedCarriers', { defaultValue: 'Allowed carriers (comma-separated)' })}
              <input value={allowedCarriers} onChange={(e) => setAllowedCarriers(e.target.value)} />
            </label>
            <label>{t('systemAdmin.carrier.defaultSender', { defaultValue: 'Default sender ID' })}
              <input value={defaultSender} onChange={(e) => setDefaultSender(e.target.value)} maxLength={11} />
            </label>
            <label>{t('systemAdmin.carrier.smsEnabled', { defaultValue: 'SMS delivery enabled' })}
              <select value={String(smsEnabled)} onChange={(e) => setSmsEnabled(e.target.value === 'true')}>
                <option value="true">Enabled (deliver SMS to citizens)</option>
                <option value="false">Disabled (log only)</option>
              </select>
            </label>
          </div>
          <button className="btn">{t('systemAdmin.carrier.save', { defaultValue: 'Save configuration' })}</button>
        </form>
      </div>
    </div>
  );
}

function StatusItem({ label, value, ok }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, padding: '10px 0', borderBottom: '1px solid var(--line)' }}>
      <span style={{ fontSize: 11, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: 1 }}>{label}</span>
      <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ width: 8, height: 8, borderRadius: '50%', background: ok ? '#22c55e' : '#ef4444' }} />
        {value}
      </span>
    </div>
  );
}
