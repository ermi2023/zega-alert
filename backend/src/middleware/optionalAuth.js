import { query } from '../config/db.js';
import { verifyToken } from '../utils/jwt.js';

export const optionalAuth = async (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return next();
  try {
    const payload = verifyToken(token);
    const { rows } = await query(
      'SELECT id, full_name, phone, email, role, region, sub_city, woreda, is_active, token_version FROM users WHERE id = $1',
      [payload.sub],
    );
    if (rows[0] && rows[0].is_active && ((payload.ver ?? 0) === (rows[0].token_version ?? 0))) {
      req.user = rows[0];
    }
  } catch (_) {}
  next();
};
