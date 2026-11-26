import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { hashPassword } from '../utils/password.js';
import { writeAudit } from '../utils/audit.js';
import { io } from '../socket/socket.js';
import { getSecurityPolicy, validatePassword } from '../services/security-policy.service.js';
import { decrypt, encrypt } from '../utils/crypto.js';

const presentFanRecord = (record) => ({
  ...record,
  full_name: decrypt(record.full_name),
  phone: decrypt(record.phone),
});

const isFanRecordSchemaError = (error) =>
  ['42P01', '42703', '42704', '22001', '23514'].includes(error?.code);

const failIfFanRecordSchemaIsNotReady = (res, error) => {
  if (!isFanRecordSchemaError(error)) return false;
  fail(
    res,
    'FAN record storage is not updated yet. An administrator must apply the latest database migration before records can be saved.',
    503,
  );
  return true;
};

/**
 * GET /api/admin/stats
 * Aggregated platform telemetry for the System Admin dashboard (spec §2).
 * Includes per-role user counts, active vs suspended accounts, legal content
 * publication status, and audit/notification counts — in addition to the
 * existing reports / sos / missing-persons telemetry.
 */
export const stats = async (req, res) => {
  const [
    users,
    usersByRole,
    activeCounts,
    reports,
    sos,
    missing,
    wanted,
    dispatches,
    recentReports,
    monthlyTrend,
    legalOverview,
    auditCount,
    notificationCount,
    regions,
    geofences,
  ] = await Promise.all([
    query(`SELECT COUNT(*)::int AS total,
      COUNT(*) FILTER (WHERE role='citizen')::int AS citizens,
      COUNT(*) FILTER (WHERE role!='citizen')::int AS staff,
      COUNT(*) FILTER (WHERE role='police' AND is_active=true)::int AS active_officers
      FROM users`),
    query(`SELECT role, COUNT(*)::int AS n, COUNT(*) FILTER (WHERE is_active=true)::int AS active FROM users GROUP BY role`),
    query(`SELECT
        COUNT(*) FILTER (WHERE is_active=true)::int  AS active,
        COUNT(*) FILTER (WHERE is_active=false)::int AS suspended
      FROM users`),
    query(`SELECT status, COUNT(*)::int AS n FROM reports GROUP BY status`),
    query(`SELECT status, COUNT(*)::int AS n,
      COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE)::int AS today
      FROM sos_alerts GROUP BY status`),
    query(`SELECT COUNT(*) FILTER (WHERE status='missing')::int AS missing,
      COUNT(*) FILTER (WHERE status='found')::int AS found FROM missing_persons`),
    query(`SELECT COUNT(*) FILTER (WHERE status='wanted')::int AS wanted,
      COUNT(*) FILTER (WHERE status='captured')::int AS captured FROM wanted_persons`),
    query(`SELECT status, COUNT(*)::int AS n FROM dispatch_assignments GROUP BY status`),
    query(`SELECT r.*, u.full_name AS reporter_name FROM reports r LEFT JOIN users u ON u.id=r.reporter_id ORDER BY r.reported_at DESC LIMIT 6`),
    query(`SELECT TO_CHAR(reported_at, 'Mon') AS label, COUNT(*)::int AS value
      FROM reports
      WHERE reported_at >= now() - interval '6 months'
      GROUP BY TO_CHAR(reported_at, 'Mon'), DATE_TRUNC('month', reported_at)
      ORDER BY DATE_TRUNC('month', reported_at) ASC`),
    // Legal content overview for the System Admin dashboard (spec §2 #10).
    query(`SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE is_published = true)::int AS published,
        COUNT(*) FILTER (WHERE review_status = 'draft')::int AS draft,
        COUNT(*) FILTER (WHERE review_status = 'under_review')::int AS under_review
      FROM legal_content`),
    // Audit log totals + 24h count (spec §2 #9 Recent Activities).
    query(`SELECT COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE created_at >= now() - interval '24 hours')::int AS last_24h
      FROM audit_log`),
    // Notification counts.
    query(`SELECT COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE is_read=false)::int AS unread
      FROM notifications`),
    query(`SELECT COALESCE(region, 'Unassigned') AS region, COUNT(*)::int AS n
      FROM users GROUP BY region ORDER BY n DESC`),
    query(`SELECT COUNT(*)::int AS total,
      COUNT(*) FILTER (WHERE is_active = true)::int AS active FROM geofences`),
  ]);

  const dbStarted = Date.now();
  await query('SELECT 1');
  const dbLatency = Date.now() - dbStarted;

  // Map role rows into an object keyed by role, including active/suspended counts.
  const roleBreakdown = {};
  for (const r of usersByRole.rows) {
    roleBreakdown[r.role] = { total: r.n, active: r.active, suspended: r.n - r.active };
  }
  // Ensure all five roles are present in the response even if zero.
  for (const role of ['system_admin', 'regional_admin', 'dispatcher', 'police', 'citizen']) {
    if (!roleBreakdown[role]) roleBreakdown[role] = { total: 0, active: 0, suspended: 0 };
  }

  const totalReports = reports.rows.reduce((sum, r) => sum + r.n, 0);
  const openCases = reports.rows
    .filter((r) => ['submitted', 'under_review', 'assigned', 'in_progress', 'pending'].includes(r.status))
    .reduce((sum, r) => sum + r.n, 0);
  const sosToday = sos.rows.reduce((sum, r) => sum + (r.today || 0), 0);

  // Pull the most recent admin activities for the activity feed (spec §2 #9).
  const recentActivity = await query(
    `SELECT a.id, a.action, a.entity, a.entity_id, a.detail, a.ip_address, a.created_at,
        u.full_name AS actor_name
     FROM audit_log a LEFT JOIN users u ON u.id = a.user_id
     ORDER BY a.created_at DESC LIMIT 10`,
  );

  ok(res, {
    users: { ...users.rows[0], ...activeCounts.rows[0], byRole: roleBreakdown },
    reports: reports.rows,
    totalReports,
    openCases,
    sosToday,
    monthlyTrend: monthlyTrend.rows,
    sos: sos.rows,
    missingPersons: missing.rows[0],
    wantedPersons: wanted.rows[0],
    dispatches: dispatches.rows,
    recentReports: recentReports.rows,
    // New System Admin dashboard fields (spec §2):
    legalOverview: legalOverview.rows[0],
    audit: auditCount.rows[0],
    notifications: notificationCount.rows[0],
    recentActivity: recentActivity.rows,
    regions: regions.rows,
    geofences: geofences.rows[0],
    system: {
      db_latency_ms: dbLatency,
      websocket_clients: io.engine?.clientsCount ?? 0,
      uptime_seconds: Math.round(process.uptime()),
      node_version: process.version,
    },
  });
};

export const listUsers = async (req, res) => {
  const { role, region, q, page = 1, limit = 20 } = req.query;
  const params = [];
  const where = [];
  if (role) { params.push(role); where.push(`role = $${params.length}`); }
  if (region) { params.push(region); where.push(`region = $${params.length}`); }
  if (q) { params.push(`%${q}%`); where.push(`(full_name ILIKE $${params.length} OR phone ILIKE $${params.length})`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  params.push(parseInt(limit, 10), (parseInt(page, 10) - 1) * parseInt(limit, 10));
  const { rows } = await query(
    `SELECT id, full_name, phone, email, role, region, sub_city, woreda, is_verified, is_identity_verified, is_active, last_login_at, created_at
     FROM users ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  ok(res, rows);
};

export const listFanRecords = async (_req, res) => {
  try {
    const { rows } = await query(
      `SELECT id, full_name, phone, fan_number, is_active, verified_user_id, verified_at, created_at
       FROM fan_verification_records ORDER BY created_at DESC`,
    );
    ok(res, rows.map(presentFanRecord));
  } catch (error) {
    if (failIfFanRecordSchemaIsNotReady(res, error)) return;
    throw error;
  }
};

export const createFanRecord = async (req, res) => {
  const body = req.body ?? {};
  const fullName = String(body.full_name ?? '').trim();
  const phone = String(body.phone ?? '').trim();
  const fanNumber = String(body.fan_number ?? '').trim();
  if (!fullName || fullName.length > 150) {
    return fail(res, 'Enter a name of 1 to 150 characters.');
  }
  if (!phone || phone.length > 32) {
    return fail(res, 'Enter a phone number of 1 to 32 characters.');
  }
  if (!/^\d{16}$/.test(fanNumber)) {
    return fail(res, 'Enter a valid 16-digit FAN number.');
  }

  try {
    const { rows } = await query(
      `INSERT INTO fan_verification_records (full_name, phone, fan_number, created_by)
       VALUES ($1, $2, $3, $4)
       RETURNING id, full_name, phone, fan_number, is_active, verified_user_id, verified_at, created_at`,
      [encrypt(fullName), encrypt(phone), fanNumber, req.user.id],
    );
    await writeAudit({
      userId: req.user.id,
      action: 'create_fan_verification_record',
      entity: 'fan_verification_records',
      entityId: rows[0].id,
      detail: { fan_number: `${fanNumber.slice(0, 4)}****${fanNumber.slice(-4)}` },
      req,
    });
    return ok(res, presentFanRecord(rows[0]), 'Mock ID record added', 201);
  } catch (error) {
    if (error.code === '23505') {
      return fail(res, 'That FAN number is already in the verification records.', 409);
    }
    if (failIfFanRecordSchemaIsNotReady(res, error)) return;
    throw error;
  }
};

export const updateFanRecord = async (req, res) => {
  const body = req.body ?? {};
  if (typeof body.is_active !== 'boolean') {
    return fail(res, 'is_active must be true or false.');
  }
  let rows;
  try {
    ({ rows } = await query(
      `UPDATE fan_verification_records SET is_active = $1, updated_at = now()
       WHERE id = $2
       RETURNING id, full_name, phone, fan_number, is_active, verified_user_id, verified_at, created_at`,
      [body.is_active, req.params.id],
    ));
  } catch (error) {
    if (failIfFanRecordSchemaIsNotReady(res, error)) return;
    throw error;
  }
  if (!rows[0]) return fail(res, 'FAN record not found.', 404);
  await writeAudit({
    userId: req.user.id,
    action: body.is_active ? 'activate_fan_verification_record' : 'deactivate_fan_verification_record',
    entity: 'fan_verification_records',
    entityId: rows[0].id,
    detail: { fan_number: `${rows[0].fan_number.slice(0, 4)}****${rows[0].fan_number.slice(-4)}` },
    req,
  });
  return ok(res, presentFanRecord(rows[0]), 'FAN record updated');
};

export const createUser = async (req, res) => {
  const { full_name, phone, email, password, role, region, sub_city, woreda } = req.body;
  if (!full_name || !phone || !password || !role) return fail(res, 'full_name, phone, password, role required');
  const passwordError = validatePassword(password, await getSecurityPolicy());
  if (passwordError) return fail(res, passwordError);
  const password_hash = await hashPassword(password);
  const { rows } = await query(
    `INSERT INTO users (full_name, phone, email, password_hash, role, region, sub_city, woreda, is_verified)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true) RETURNING id, full_name, phone, role, region, is_verified, is_active, created_at`,
    [full_name, phone, email || null, password_hash, role, region || null, sub_city || null, woreda || null],
  );
  // Audit the account creation (spec §3.2 + business rule §14.3).
  await writeAudit({
    userId: req.user.id,
    action: 'create_user',
    entity: 'users',
    entityId: rows[0].id,
    detail: {
      full_name: rows[0].full_name,
      phone: rows[0].phone,
      role: rows[0].role,
      region: rows[0].region,
      created_by: req.user.role,
    },
    req,
  });
  ok(res, rows[0], 'User created', 201);
};

export const updateUser = async (req, res) => {
  const { full_name, phone, role, region, sub_city, woreda, is_active } = req.body;
  const validRoles = ['citizen', 'police', 'dispatcher', 'regional_admin', 'system_admin'];
  if (role && !validRoles.includes(role)) return fail(res, `role must be one of ${validRoles.join(', ')}`);

  const target = await query('SELECT id, role, is_active, phone FROM users WHERE id = $1', [req.params.id]);
  if (!target.rows[0]) return fail(res, 'User not found', 404);
  const current = target.rows[0];

  let normalizedPhone = current.phone;
  if (phone !== undefined) {
    const np = String(phone).replace(/[\s\-()]/g, '');
    let p = np;
    if (p.startsWith('+251')) p = p.slice(4);
    else if (p.startsWith('251') && p.length > 9) p = p.slice(3);
    if (p && !p.startsWith('0')) p = p.length === 9 ? `0${p}` : p;
    if (p.length < 9) return fail(res, 'Enter a valid phone number, e.g. 0911234567');
    const dup = await query('SELECT id FROM users WHERE phone = $1 AND id <> $2', [p, req.params.id]);
    if (dup.rows.length) return fail(res, 'That phone number is already in use', 409);
    normalizedPhone = p;
  }

  // Prevent demoting or disabling the last active System Admin (doc 4.3.6).
  const losingAdmin = current.role === 'system_admin' &&
    ((role && role !== 'system_admin') || is_active === false);
  if (losingAdmin) {
    const count = await query(
      `SELECT COUNT(*)::int AS n FROM users WHERE role = 'system_admin' AND is_active = true AND id <> $1`,
      [req.params.id],
    );
    if (count.rows[0].n === 0) {
      return fail(res, 'Cannot demote or disable the last active System Admin', 409);
    }
  }

  // Warn before suspending an account with active casework (doc 4.3.6).
  if (is_active === false && current.is_active === true && !req.body.confirm_active_cases) {
    const activeCases = await query(
      `SELECT (
         (SELECT COUNT(*) FROM reports WHERE assigned_to = $1 AND status IN ('draft','pending','submitted','under_review','assigned','in_progress','verified')) +
         (SELECT COUNT(*) FROM sos_alerts WHERE dispatcher_id = $1 AND status IN ('triggered','acknowledged','dispatched')) +
         (SELECT COUNT(*) FROM dispatch_assignments WHERE assigned_to = $1 AND status <> 'completed') +
         (SELECT COUNT(*) FROM reports WHERE reporter_id = $1 AND status IN ('draft','pending','submitted','under_review','assigned','in_progress','verified'))
       )::int AS n`,
      [req.params.id],
    );
    if (activeCases.rows[0].n > 0) {
      return fail(res, `This account has ${activeCases.rows[0].n} active case(s). Resend with confirm_active_cases=true to suspend anyway.`, 409);
    }
  }

  const { rows } = await query(
    `UPDATE users SET full_name = COALESCE($1, full_name), phone = COALESCE($2, phone), role = COALESCE($3, role),
       region = COALESCE($4, region), sub_city = COALESCE($5, sub_city), woreda = COALESCE($6, woreda),
       is_active = COALESCE($7, is_active), updated_at = now()
      WHERE id = $8 RETURNING id, full_name, phone, role, region, is_active, updated_at`,
    [full_name || null, phone !== undefined ? normalizedPhone : null, role || null, region || null, sub_city || null, woreda || null,
      is_active ?? null, req.params.id],
  );
  if (!rows[0]) return fail(res, 'User not found', 404);

  const updated = rows[0];

  // Emit distinct audit rows for the most security-relevant changes so the
  // Audit Log page can filter on them (spec §8.3 — record role assignment,
  // permission changes, account suspension). A generic update_user row is
  // always written; specific actions are appended when they occurred.
  const auditDetail = { ...req.body, target_id: updated.id, target_name: updated.full_name };
  if (role && current.role !== role) {
    auditDetail.role_change = { from: current.role, to: role };
  }
  if (is_active === false && current.is_active === true) {
    auditDetail.suspended = true;
  }
  if (is_active === true && current.is_active === false) {
    auditDetail.reactivated = true;
  }

  await writeAudit({
    userId: req.user.id,
    action: 'update_user',
    entity: 'users',
    entityId: updated.id,
    detail: auditDetail,
    req,
  });

  // Distinct rows for the high-signal changes (filtered easily in the UI).
  if (auditDetail.role_change) {
    await writeAudit({
      userId: req.user.id,
      action: 'change_role',
      entity: 'users',
      entityId: updated.id,
      detail: auditDetail.role_change,
      req,
    });
  }
  if (auditDetail.suspended) {
    await writeAudit({
      userId: req.user.id,
      action: 'suspend_user',
      entity: 'users',
      entityId: updated.id,
      detail: { reason: req.body.suspend_reason || req.body.reason || 'Suspended by admin' },
      req,
    });
  }
  if (auditDetail.reactivated) {
    await writeAudit({
      userId: req.user.id,
      action: 'activate_user',
      entity: 'users',
      entityId: updated.id,
      detail: { note: 'Reactivated by admin' },
      req,
    });
  }

  ok(res, updated, 'User updated');
};

export const deleteUser = async (req, res) => {
  const target = await query('SELECT id, role, full_name FROM users WHERE id = $1', [req.params.id]);
  if (!target.rows[0]) return fail(res, 'User not found', 404);
  const t = target.rows[0];
  if (t.id === req.user.id) return fail(res, 'You cannot delete your own account', 409);

  // Prevent deleting the last System Admin (doc 4.3.6).
  if (t.role === 'system_admin') {
    const count = await query(
      `SELECT COUNT(*)::int AS n FROM users WHERE role = 'system_admin' AND id <> $1`,
      [t.id],
    );
    if (count.rows[0].n === 0) {
      return fail(res, 'Cannot delete the last System Admin', 409);
    }
  }

  // Warn before deleting an account with active casework (doc 4.3.6).
  if (!req.body.confirm_active_cases) {
    const activeCases = await query(
      `SELECT (
         (SELECT COUNT(*) FROM reports WHERE assigned_to = $1 AND status IN ('draft','pending','submitted','under_review','assigned','in_progress','verified')) +
         (SELECT COUNT(*) FROM sos_alerts WHERE dispatcher_id = $1 AND status IN ('triggered','acknowledged','dispatched')) +
         (SELECT COUNT(*) FROM dispatch_assignments WHERE assigned_to = $1 AND status <> 'completed') +
         (SELECT COUNT(*) FROM reports WHERE reporter_id = $1 AND status IN ('draft','pending','submitted','under_review','assigned','in_progress','verified'))
       )::int AS n`,
      [t.id],
    );
    if (activeCases.rows[0].n > 0) {
      return fail(res, `This account has ${activeCases.rows[0].n} active case(s). Resend with confirm_active_cases=true to delete anyway.`, 409);
    }
  }

  await query('DELETE FROM users WHERE id = $1', [t.id]);
  await writeAudit({
    userId: req.user.id,
    action: 'delete_user',
    entity: 'users',
    entityId: t.id,
    detail: { full_name: t.full_name, role: t.role, deleted_by: req.user.role },
    req,
  });
  ok(res, null, 'User deleted');
};

export const listAudit = async (req, res) => {
  const { page = 1, limit = 30, action, entity, user_id, q, from, to } = req.query;
  const params = [];
  const where = [];

  if (action) { params.push(action); where.push(`a.action = $${params.length}`); }
  if (entity) { params.push(entity); where.push(`a.entity = $${params.length}`); }
  if (user_id) { params.push(user_id); where.push(`a.user_id = $${params.length}`); }
  if (q) { params.push(`%${q}%`); where.push(`(a.action ILIKE $${params.length} OR u.full_name ILIKE $${params.length})`); }
  if (from) { params.push(from); where.push(`a.created_at >= $${params.length}::timestamptz`); }
  if (to) { params.push(to); where.push(`a.created_at <= $${params.length}::timestamptz`); }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const countResult = await query(
    `SELECT COUNT(*)::int AS total FROM audit_log a LEFT JOIN users u ON u.id = a.user_id ${whereSql}`,
    params,
  );
  const total = countResult.rows[0]?.total || 0;

  params.push(parseInt(limit, 10), (parseInt(page, 10) - 1) * parseInt(limit, 10));
  const { rows } = await query(
    `SELECT a.*, u.full_name FROM audit_log a LEFT JOIN users u ON u.id = a.user_id
     ${whereSql} ORDER BY a.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );

  ok(res, {
    items: rows,
    total,
    page: parseInt(page, 10),
    limit: parseInt(limit, 10),
    totalPages: Math.ceil(total / parseInt(limit, 10)),
  });
};

export const listDispatches = async (req, res) => {
  const { status } = req.query;
  const params = [];
  let whereSql = '';
  if (status) { params.push(status); whereSql = 'WHERE d.status = $1'; }
  const { rows } = await query(
    `SELECT d.*, s.latitude, s.longitude, s.address_text, su.full_name AS sos_user,
       a.full_name AS assigned_name
     FROM dispatch_assignments d
     LEFT JOIN sos_alerts s ON s.id = d.sos_id
     LEFT JOIN users su ON su.id = s.user_id
     LEFT JOIN users a ON a.id = d.assigned_to
     ${whereSql} ORDER BY d.created_at DESC LIMIT 100`,
    params,
  );
  ok(res, rows);
};
