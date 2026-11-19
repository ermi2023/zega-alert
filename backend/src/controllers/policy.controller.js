import { query } from '../config/db.js';
import { ok } from '../utils/response.js';
import { writeAudit } from '../utils/audit.js';

// Default security policy (spec §4.3.7 / SD-7). Used when no policy has ever
// been persisted, and as the merge base for partial updates.
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

/**
 * GET /api/policy
 * Returns the currently effective security policy.
 * Read: any authenticated user (the policy affects everyone).
 */
export const getPolicy = async (req, res) => {
  const { rows } = await query(
    `SELECT detail FROM audit_log WHERE action = 'set_security_policy' ORDER BY created_at DESC LIMIT 1`,
  );
  if (rows.length > 0) {
    return ok(res, { ...DEFAULT_POLICY, ...(rows[0].detail || {}) });
  }
  ok(res, DEFAULT_POLICY);
};

/**
 * PUT /api/policy   (system_admin only — enforced in routes)
 * Merges the body onto the current effective policy and records a single
 * audit_log row whose `detail` includes BOTH the previous and new policy so
 * the System Admin can review changes from the Audit Log page.
 */
export const updatePolicy = async (req, res) => {
  // Get the previous effective policy.
  const prevRows = await query(
    `SELECT detail FROM audit_log WHERE action = 'set_security_policy' ORDER BY created_at DESC LIMIT 1`,
  );
  const previous = prevRows.rows.length
    ? { ...DEFAULT_POLICY, ...(prevRows.rows[0].detail || {}) }
    : { ...DEFAULT_POLICY };

  // Shallow-merge with the new body. Don't accept unknown keys.
  const incoming = {};
  for (const k of Object.keys(DEFAULT_POLICY)) {
    if (req.body[k] !== undefined) incoming[k] = req.body[k];
  }
  const next = { ...previous, ...incoming };

  // Compute a tiny diff so audit_log can show what actually changed.
  const diff = {};
  for (const k of Object.keys(incoming)) {
    if (JSON.stringify(previous[k]) !== JSON.stringify(next[k])) {
      diff[k] = { from: previous[k], to: next[k] };
    }
  }

  await writeAudit({
    userId: req.user.id,
    action: 'set_security_policy',
    entity: 'system',
    entityId: null, // no row in a table — entity_id UUID, kept NULL on purpose
    detail: {
      previous,
      next,
      diff,
      actor_role: req.user.role,
    },
    req,
  });

  ok(res, next, 'Security policy updated');
};
