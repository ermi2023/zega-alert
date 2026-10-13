import { verifyToken } from '../utils/jwt.js';
import { query } from '../config/db.js';
import { fail } from '../utils/response.js';

export const authenticate = async (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return fail(res, 'Authentication required', 401);
  try {
    const payload = verifyToken(token);
    const { rows } = await query(
      'SELECT id, full_name, phone, email, role, region, sub_city, woreda, is_active, token_version FROM users WHERE id = $1',
      [payload.sub],
    );
    if (!rows[0] || !rows[0].is_active) return fail(res, 'Account not found or disabled', 401);
    // Reject tokens issued before the last logout / invalidation.
    if ((payload.ver ?? 0) !== (rows[0].token_version ?? 0)) {
      return fail(res, 'Session expired, please log in again', 401);
    }
    req.user = rows[0];
    next();
  } catch (e) {
    return fail(res, 'Invalid or expired token', 401);
  }
};

export const requireRole = (...roles) => (req, res, next) => {
  if (!req.user) return fail(res, 'Authentication required', 401);
  if (!roles.includes(req.user.role)) return fail(res, 'Forbidden: insufficient role', 403);
  next();
};
