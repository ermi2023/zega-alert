import { query } from '../config/db.js';
import { ok } from '../utils/response.js';

// Default security policy
const DEFAULT_POLICY = {
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

export const getPolicy = async (req, res) => {
  // Check if policy exists in DB
  const { rows } = await query(
    `SELECT detail FROM audit_log WHERE action = 'set_security_policy' ORDER BY created_at DESC LIMIT 1`,
  );
  if (rows.length > 0) {
    return ok(res, rows[0].detail);
  }
  ok(res, DEFAULT_POLICY);
};

export const updatePolicy = async (req, res) => {
  const policy = { ...DEFAULT_POLICY, ...req.body };
  
  // Save to audit log (as config change)
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail)
     VALUES ($1, 'set_security_policy', 'system', 'policy', $2)`,
    [req.user.id, JSON.stringify(policy)],
  );

  ok(res, policy, 'Security policy updated');
};
