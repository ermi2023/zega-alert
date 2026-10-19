import { query } from '../config/db.js';
import { ok } from '../utils/response.js';

// Staff directory for dispatch/officer-assignment screens. Unlike /api/admin/users
// (system_admin + regional_admin only) this is available to every internal role so
// dispatchers and police can load the officer roster without a 403.
export const listStaff = async (req, res) => {
  const { role, region, limit = 200 } = req.query;
  const params = [];
  const where = ['is_active = true'];
  // Default listing is staff only; citizen roster is returned only when
  // explicitly requested (callback request screen).
  if (role) {
    if (role !== 'citizen') where.push(`role != 'citizen'`);
    params.push(role);
    where.push(`role = $${params.length}`);
  } else {
    where.push(`role != 'citizen'`);
  }
  if (region) { params.push(region); where.push(`region = $${params.length}`); }
  params.push(Math.min(parseInt(limit, 10) || 200, 500));

  const { rows } = await query(
    `SELECT id, full_name, phone, role, region, sub_city, is_active, last_login_at
     FROM users WHERE ${where.join(' AND ')}
     ORDER BY full_name ASC LIMIT $${params.length}`,
    params,
  );
  ok(res, rows);
};
