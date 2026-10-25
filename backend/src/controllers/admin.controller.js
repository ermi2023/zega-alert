import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { hashPassword } from '../utils/password.js';

export const stats = async (req, res) => {
  const [users, reports, sos, missing, wanted, dispatches, recentReports, monthlyTrend] = await Promise.all([
    query(`SELECT COUNT(*)::int AS total,
      COUNT(*) FILTER (WHERE role='citizen')::int AS citizens,
      COUNT(*) FILTER (WHERE role!='citizen')::int AS staff,
      COUNT(*) FILTER (WHERE role='police' AND is_active=true)::int AS active_officers
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
  ]);

  const totalReports = reports.rows.reduce((sum, r) => sum + r.n, 0);
  const openCases = reports.rows
    .filter((r) => ['submitted', 'under_review', 'assigned', 'in_progress', 'pending'].includes(r.status))
    .reduce((sum, r) => sum + r.n, 0);
  const sosToday = sos.rows.reduce((sum, r) => sum + (r.today || 0), 0);

  ok(res, {
    users: users.rows[0],
    reports: reports.rows,
    totalReports,
    openCases,
    sosToday,
    monthlyTrend: monthlyTrend.rows.length ? monthlyTrend.rows : [
      { label: 'Jan', value: 12 }, { label: 'Feb', value: 19 }, { label: 'Mar', value: 15 },
      { label: 'Apr', value: 24 }, { label: 'May', value: 18 }, { label: 'Jun', value: 22 },
    ],
    sos: sos.rows,
    missingPersons: missing.rows[0],
    wantedPersons: wanted.rows[0],
    dispatches: dispatches.rows,
    recentReports: recentReports.rows,
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
    `SELECT id, full_name, phone, email, role, region, sub_city, woreda, is_verified, is_active, last_login_at, created_at
     FROM users ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  ok(res, rows);
};

export const createUser = async (req, res) => {
  const { full_name, phone, email, password, role, region, sub_city, woreda } = req.body;
  if (!full_name || !phone || !password || !role) return fail(res, 'full_name, phone, password, role required');
  const password_hash = await hashPassword(password);
  const { rows } = await query(
    `INSERT INTO users (full_name, phone, email, password_hash, role, region, sub_city, woreda, is_verified)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true) RETURNING id, full_name, phone, role, region, is_verified, is_active, created_at`,
    [full_name, phone, email || null, password_hash, role, region || null, sub_city || null, woreda || null],
  );
  ok(res, rows[0], 'User created', 201);
};

export const updateUser = async (req, res) => {
  const { full_name, role, region, sub_city, woreda, is_active } = req.body;
  const validRoles = ['citizen', 'police', 'dispatcher', 'regional_admin', 'system_admin'];
  if (role && !validRoles.includes(role)) return fail(res, `role must be one of ${validRoles.join(', ')}`);

  const target = await query('SELECT id, role, is_active FROM users WHERE id = $1', [req.params.id]);
  if (!target.rows[0]) return fail(res, 'User not found', 404);
  const current = target.rows[0];

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
    `UPDATE users SET full_name = COALESCE($1, full_name), role = COALESCE($2, role),
       region = COALESCE($3, region), sub_city = COALESCE($4, sub_city), woreda = COALESCE($5, woreda),
       is_active = COALESCE($6, is_active), updated_at = now()
     WHERE id = $7 RETURNING id, full_name, phone, role, region, is_active, updated_at`,
    [full_name || null, role || null, region || null, sub_city || null, woreda || null,
      is_active ?? null, req.params.id],
  );
  if (!rows[0]) return fail(res, 'User not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,'update_user','users',$2,$3)`,
    [req.user.id, rows[0].id, JSON.stringify(req.body)],
  );
  ok(res, rows[0], 'User updated');
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
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail)
     VALUES ($1,'delete_user','users',$2,$3)`,
    [req.user.id, t.id, JSON.stringify({ full_name: t.full_name, role: t.role })],
  );
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
