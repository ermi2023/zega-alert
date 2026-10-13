import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

export default function SecurityPolicy() {
  const { t } = useTranslation();
  const [policy, setPolicy] = useState(null);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [editing, setEditing] = useState(false);

  useEffect(() => {
    api.get('/policy').then(setPolicy).catch(() => {});
  }, []);

  const save = async () => {
    try {
      const updated = await api.put('/policy', policy);
      setPolicy(updated);
      setEditing(false);
      setMsg({ type: 'ok', text: t('security.saved') });
    } catch (e) {
      setMsg({ type: 'err', text: t('security.failed') + e.message });
    }
  };

  const update = (key, value) => setPolicy({ ...policy, [key]: value });

  if (!policy) return <div><h1>{t('security.title')}</h1><p>{t('loading')}</p></div>;

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('security.title')}</h1>
          <p>{t('security.subtitle')}</p>
        </div>
        <div className="filters">
          {editing ? (
            <>
              <button className="btn" onClick={save}>{t('security.saveChanges')}</button>
              <button className="btn ghost" onClick={() => setEditing(false)}>{t('security.cancel')}</button>
            </>
          ) : (
            <button className="btn" onClick={() => setEditing(true)}>{t('security.editPolicy')}</button>
          )}
        </div>
      </div>

      {msg.text && <div className={`msg ${msg.type}`} style={{ marginBottom: 16 }}>{msg.text}</div>}

      <div className="grid-2">
        {/* Password Policy */}
        <div className="panel">
          <h2>🔑 {t('security.passwordPolicy')}</h2>
          <label>
            {t('security.minLength')}
            <input type="number" value={policy.password_min_length} disabled={!editing}
              onChange={(e) => update('password_min_length', parseInt(e.target.value))} />
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
            <input type="checkbox" checked={policy.password_require_uppercase} disabled={!editing}
              onChange={(e) => update('password_require_uppercase', e.target.checked)} />
            {t('security.requireUppercase')}
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
            <input type="checkbox" checked={policy.password_require_numbers} disabled={!editing}
              onChange={(e) => update('password_require_numbers', e.target.checked)} />
            {t('security.requireNumbers')}
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
            <input type="checkbox" checked={policy.password_require_special} disabled={!editing}
              onChange={(e) => update('password_require_special', e.target.checked)} />
            {t('security.requireSpecial')}
          </label>
        </div>

        {/* Session & Login */}
        <div className="panel">
          <h2>🔐 {t('security.sessionLogin')}</h2>
          <label>
            {t('security.sessionTimeout')}
            <input type="number" value={policy.session_timeout_minutes} disabled={!editing}
              onChange={(e) => update('session_timeout_minutes', parseInt(e.target.value))} />
          </label>
          <label>
            {t('security.maxLoginAttempts')}
            <input type="number" value={policy.max_login_attempts} disabled={!editing}
              onChange={(e) => update('max_login_attempts', parseInt(e.target.value))} />
          </label>
          <label>
            {t('security.lockoutDuration')}
            <input type="number" value={policy.lockout_duration_minutes} disabled={!editing}
              onChange={(e) => update('lockout_duration_minutes', parseInt(e.target.value))} />
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
            <input type="checkbox" checked={policy.mfa_enabled} disabled={!editing}
              onChange={(e) => update('mfa_enabled', e.target.checked)} />
            {t('security.enableMfa')}
          </label>
        </div>

        {/* Data & Encryption */}
        <div className="panel">
          <h2>🛡 {t('security.dataEncryption')}</h2>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <input type="checkbox" checked={policy.tls_enforced} disabled={!editing}
              onChange={(e) => update('tls_enforced', e.target.checked)} />
            {t('security.tlsEnforcement')}
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
            <input type="checkbox" checked={policy.encryption_at_rest} disabled={!editing}
              onChange={(e) => update('encryption_at_rest', e.target.checked)} />
            {t('security.aesEncryption')}
          </label>
          <label>
            {t('security.dataRetention')}
            <input type="number" value={policy.data_retention_days} disabled={!editing}
              onChange={(e) => update('data_retention_days', parseInt(e.target.value))} />
          </label>
          <label>
            {t('security.auditRetention')}
            <input type="number" value={policy.audit_log_retention_days} disabled={!editing}
              onChange={(e) => update('audit_log_retention_days', parseInt(e.target.value))} />
          </label>
        </div>

        {/* Rate Limiting & API */}
        <div className="panel">
          <h2>⚡ {t('security.rateLimiting')}</h2>
          <label>
            {t('security.rateLimit')}
            <input type="number" value={policy.rate_limit_per_minute} disabled={!editing}
              onChange={(e) => update('rate_limit_per_minute', parseInt(e.target.value))} />
          </label>
          <label>
            {t('security.apiKeyRotation')}
            <input type="number" value={policy.api_key_rotation_days} disabled={!editing}
              onChange={(e) => update('api_key_rotation_days', parseInt(e.target.value))} />
          </label>
          <h3 style={{ marginTop: 16 }}>{t('security.allowedCarriers')}</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
            {(policy.allowed_carriers || []).map((c) => (
              <span key={c} style={{ padding: '4px 8px', borderRadius: 6, background: '#e8f5e9', fontSize: 13 }}>
                {c}
                {editing && (
                  <button onClick={() => update('allowed_carriers', policy.allowed_carriers.filter(x => x !== c))}
                    style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'red', marginLeft: 4 }}>&times;</button>
                )}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
