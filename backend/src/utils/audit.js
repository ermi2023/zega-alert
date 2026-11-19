/**
 * Centralized audit-log writer.
 *
 * Single source of truth for `INSERT INTO audit_log` so every admin/staff
 * action goes through one place. Captures `ip_address` (which the previous
 * inline calls all dropped) and normalizes the detail JSON.
 *
 * Spec §4.3.6 / SD-9: every important administrative action must be recorded.
 */
import { query } from '../config/db.js';

/**
 * Write one audit_log row. Never throws — audit failures must not break the
 * business action that triggered them. Returns the inserted row or null.
 *
 * @param {object} args
 * @param {string|import('pg').types} args.userId   actor user id (UUID)
 * @param {string} args.action                       short machine action key, e.g. 'create_user'
 * @param {string} [args.entity]                     affected table/module, e.g. 'users'
 * @param {string} [args.entityId]                   affected row id (UUID or null)
 * @param {object|string} [args.detail]              arbitrary JSONB payload
 * @param {string} [args.ip]                         request IP (req.ip)
 * @param {object} [args.req]                       optional Express req, used to pull ip if not given
 */
export async function writeAudit({ userId, action, entity = null, entityId = null, detail = null, ip = null, req = null }) {
  try {
    const ipAddr = ip || req?.ip || null;
    // entity_id is UUID; coerce null/empty/string-'policy' to NULL so we don't
    // hit the old UUID-cast bug from policy.controller.js.
    const safeEntityId = entityId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(entityId))
      ? entityId
      : null;
    const detailJson = detail == null ? null : (typeof detail === 'string' ? detail : JSON.stringify(detail));
    const { rows } = await query(
      `INSERT INTO audit_log (user_id, action, entity, entity_id, detail, ip_address)
       VALUES ($1, $2, $3, $4, $5::jsonb, $6)
       RETURNING id, action, entity, entity_id, created_at, ip_address`,
      [userId ?? null, action, entity, safeEntityId, detailJson, ipAddr],
    );
    return rows[0] || null;
  } catch (err) {
    // Audit failure must never break the user-facing action.
    console.error('[AUDIT] writeAudit failed:', err.message, { action, entity, entityId });
    return null;
  }
}

/**
 * Express middleware that auto-writes an audit row *after* a successful
 * handler. Use sparingly — for most flows an explicit writeAudit() call in
 * the controller is clearer (you can include the row id / diff).
 *
 *   router.post('/users', audit('create_user', 'users'), createUser);
 *
 * The middleware reads req.user.id (set by `authenticate`) and, if the
 * handler put the created entity on req.auditEntity, uses that as entity_id.
 */
export function audit(action, entity = null) {
  return (req, res, next) => {
    // Hook the response finish to write audit only on 2xx.
    res.on('finish', () => {
      if (res.statusCode >= 200 && res.statusCode < 300 && req.user?.id) {
        const entityId = req.auditEntity?.id || req.params?.id || null;
        writeAudit({
          userId: req.user.id,
          action,
          entity,
          entityId,
          detail: req.auditDetail || null,
          req,
        });
      }
    });
    next();
  };
}
