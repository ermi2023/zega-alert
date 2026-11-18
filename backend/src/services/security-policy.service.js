import { query } from '../config/db.js';

export const DEFAULT_POLICY = {
  password_min_length: 8,
  password_require_uppercase: true,
  password_require_numbers: true,
  password_require_special: true,
  session_timeout_minutes: 60,
  max_login_attempts: 5,
  lockout_duration_minutes: 30,
  mfa_enabled: false,
  data_retention_days: 365,
  audit_log_retention_days: 730,
  tls_enforced: true,
  encryption_at_rest: true,
  rate_limit_per_minute: 100,
  api_key_rotation_days: 90,
  allowed_carriers: ['Ethio Telecom', 'Safaricom Ethiopia'],
  custom_rules: [],
};

export const getSecurityPolicy = async () => {
  const { rows } = await query(
    `SELECT detail FROM audit_log WHERE action = 'set_security_policy' ORDER BY created_at DESC LIMIT 1`,
  );
  if (!rows[0]?.detail) return DEFAULT_POLICY;
  return { ...DEFAULT_POLICY, ...rows[0].detail };
};

export const validatePassword = (password, policy) => {
  const value = String(password || '');
  if (value.length < (policy.password_min_length || 8)) {
    return `Password must be at least ${policy.password_min_length || 8} characters`;
  }
  if (policy.password_require_uppercase && !/[A-Z]/.test(value)) {
    return 'Password must include an uppercase letter';
  }
  if (policy.password_require_numbers && !/[0-9]/.test(value)) {
    return 'Password must include a number';
  }
  if (policy.password_require_special && !/[^A-Za-z0-9]/.test(value)) {
    return 'Password must include a special character';
  }
  return null;
};

export const accessTokenExpiry = (policy) => {
  const minutes = Math.max(5, Number(policy.session_timeout_minutes) || 60);
  return `${minutes}m`;
};
