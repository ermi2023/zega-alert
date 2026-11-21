import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { writeAudit } from '../utils/audit.js';
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

const readPolicy = async () => {
  const { rows } = await query(
    `SELECT detail FROM audit_log WHERE action = 'set_security_policy' ORDER BY created_at DESC LIMIT 1`,
  );
  const detail = rows[0]?.detail;
  if (detail && typeof detail === 'object' && detail.next && typeof detail.next === 'object') {
    return { ...DEFAULT_POLICY, ...detail.next };
  }
  return getSecurityPolicy();
};

/**
 * GET /api/policy
 * Returns the currently effective security policy.
 * Read: any authenticated user (the policy affects everyone).
 */
export const getPolicy = async (req, res) => {
  ok(res, await readPolicy());
};

/**
 * PUT /api/policy   (system_admin only — enforced in routes)
 * Merges the body onto the current effective policy and records a single
 * audit_log row whose `detail` includes BOTH the previous and new policy so
 * the System Admin can review changes from the Audit Log page.
 */
export const updatePolicy = async (req, res) => {
  const previous = await readPolicy();

  const incoming = {};
  for (const k of Object.keys(DEFAULT_POLICY)) {
    if (req.body[k] !== undefined) incoming[k] = req.body[k];
  }
  const next = { ...previous, ...incoming };

  for (const [key, [min, max]] of Object.entries(NUMBER_FIELDS)) {
    const n = Number(next[key]);
    if (!Number.isFinite(n) || n < min || n > max) {
      return fail(res, `${key} must be between ${min} and ${max}`);
    }
    next[key] = Math.round(n);
  }
  if (!Array.isArray(next.allowed_carriers)) {
    return fail(res, 'allowed_carriers must be an array');
  }

  const diff = {};
  for (const k of Object.keys(incoming)) {
    if (JSON.stringify(previous[k]) !== JSON.stringify(next[k])) {
      diff[k] = { from: previous[k], to: next[k] };
    }
  }

  try {
    await writeAudit({
      userId: req.user.id,
      action: 'set_security_policy',
      entity: 'system',
      entityId: null,
      detail: {
        ...next,
        previous,
        next,
        diff,
        actor_role: req.user.role,
      },
      req,
    });
  } catch (err) {
    console.error('[policy] audit write failed:', err.message);
  }

  ok(res, next, 'Security policy updated');
};
