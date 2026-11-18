import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { DEFAULT_POLICY, getSecurityPolicy } from '../services/security-policy.service.js';

const NUMBER_FIELDS = {
  password_min_length: [4, 64],
  session_timeout_minutes: [5, 1440],
  max_login_attempts: [3, 20],
  lockout_duration_minutes: [1, 1440],
  data_retention_days: [1, 3650],
  audit_log_retention_days: [1, 3650],
  rate_limit_per_minute: [10, 10000],
  api_key_rotation_days: [1, 365],
};

export const getPolicy = async (req, res) => {
  ok(res, await getSecurityPolicy());
};

export const updatePolicy = async (req, res) => {
  const policy = { ...DEFAULT_POLICY, ...req.body };
  for (const [key, [min, max]] of Object.entries(NUMBER_FIELDS)) {
    const n = Number(policy[key]);
    if (!Number.isFinite(n) || n < min || n > max) {
      return fail(res, `${key} must be between ${min} and ${max}`);
    }
    policy[key] = Math.round(n);
  }
  if (!Array.isArray(policy.allowed_carriers)) {
    return fail(res, 'allowed_carriers must be an array');
  }

  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail)
     VALUES ($1, 'set_security_policy', 'system', 'policy', $2)`,
    [req.user.id, JSON.stringify(policy)],
  );

  ok(res, policy, 'Security policy updated');
};
