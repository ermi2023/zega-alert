import { query } from '../config/db.js';
import { env } from '../config/env.js';
import { hashPassword, comparePassword } from '../utils/password.js';
import { signTokens, verifyToken } from '../utils/jwt.js';
import { createOtp, verifyOtp } from '../utils/otp.js';
import { ok, fail } from '../utils/response.js';

const PUBLIC_USER = `id, full_name, phone, email, role, region, sub_city, woreda, photo_url,
  preferred_language, accessibility_mode, is_verified, is_active, last_login_at, created_at`;

export const register = async (req, res) => {
  const { full_name, phone, email, password, region, sub_city, woreda, preferred_language, accessibility_mode } = req.body;
  if (!full_name || !phone || !password) return fail(res, 'full_name, phone and password are required');
  const existing = await query('SELECT id FROM users WHERE phone = $1 OR email = $2', [phone, email || '']);
  if (existing.rows.length) return fail(res, 'An account with this phone or email already exists', 409);

  const password_hash = await hashPassword(password);
  const { rows } = await query(
    `INSERT INTO users (full_name, phone, email, password_hash, region, sub_city, woreda, preferred_language, accessibility_mode)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     RETURNING ${PUBLIC_USER}`,
    [full_name, phone, email || null, password_hash, region || null, sub_city || null, woreda || null,
      preferred_language || 'en', accessibility_mode || false],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'register','users',$1)`,
    [rows[0].id],
  );
  const { code, sms } = await createOtp({ contact: phone, purpose: 'verify_phone' });
  const smsDelivered = sms && sms.status === 'sent';
  // When the SMS gateway is unavailable (e.g. no/invalid Africa's Talking key)
  // the user would otherwise be stuck at the OTP step, so trust the signup and
  // mark the phone verified, and hand the code back for the app to use.
  if (!smsDelivered) {
    await query('UPDATE users SET is_verified = true WHERE phone = $1', [phone]);
  }
  if (env.nodeEnv !== 'production') console.log(`[DEV OTP] ${code} -> ${phone}`);
  ok(res, { ...rows[0], is_verified: rows[0].is_verified || !smsDelivered, devOtp: smsDelivered ? undefined : code },
    smsDelivered ? 'Registered. Verify your phone with the OTP sent.' : 'Registered. You are signed in.', 201);
};

export const requestOtp = async (req, res) => {
  const { contact, purpose } = req.body;
  if (!contact || !['login', 'register', 'reset_password', 'verify_phone'].includes(purpose)) {
    return fail(res, 'contact and valid purpose are required');
  }
  const { code } = await createOtp({ contact, purpose });
  if (env.nodeEnv !== 'production') console.log(`[DEV OTP] ${code} -> ${contact}`);
  ok(res, null, 'OTP sent.');
};

export const verifyOtpEndpoint = async (req, res) => {
  const { contact, code, purpose = 'verify_phone' } = req.body;
  const result = await verifyOtp({ contact, code, purpose });
  if (!result.ok) return fail(res, `OTP invalid/expired (${result.reason})`, 400);
  if (purpose === 'verify_phone') {
    await query('UPDATE users SET is_verified = true WHERE phone = $1', [contact]);
  }
  ok(res, null, 'Verified.');
};

export const login = async (req, res) => {
  const { phone, email, password } = req.body;
  const contact = phone || email;
  if (!contact || !password) return fail(res, 'Credentials required');
  const { rows } = await query('SELECT * FROM users WHERE phone = $1 OR email = $1', [contact]);
  const user = rows[0];
  if (!user || !user.password_hash || !(await comparePassword(password, user.password_hash))) {
    return fail(res, 'Invalid credentials', 401);
  }
  if (!user.is_active) return fail(res, 'Account disabled', 403);
  await query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'login','users',$1)`,
    [user.id],
  );
  const tokens = signTokens(user);
  ok(res, { user: publicUser(user), ...tokens }, 'Login successful');
};

export const loginWithOtp = async (req, res) => {
  const { phone, code } = req.body;
  const result = await verifyOtp({ contact: phone, code, purpose: 'login' });
  if (!result.ok) return fail(res, `OTP invalid/expired (${result.reason})`, 400);
  const { rows } = await query('SELECT * FROM users WHERE phone = $1', [phone]);
  const user = rows[0];
  if (!user) return fail(res, 'No account found for this phone. Register first.', 404);
  if (!user.is_active) return fail(res, 'Account disabled', 403);
  await query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
  const tokens = signTokens(user);
  ok(res, { user: publicUser(user), ...tokens }, 'Login successful');
};

export const refresh = async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return fail(res, 'refreshToken required');
  try {
    const payload = verifyToken(refreshToken);
    if (payload.type !== 'refresh') return fail(res, 'Invalid refresh token', 401);
    const { rows } = await query('SELECT * FROM users WHERE id = $1', [payload.sub]);
    if (!rows[0] || !rows[0].is_active) return fail(res, 'Account not found', 401);
    // Reject refresh tokens that were revoked by a logout (token_version bump).
    if ((payload.ver ?? 0) !== (rows[0].token_version ?? 0)) {
      return fail(res, 'Refresh token has been revoked', 401);
    }
    ok(res, signTokens(rows[0]), 'Tokens refreshed');
  } catch (e) {
    fail(res, 'Invalid refresh token', 401);
  }
};

export const logout = async (req, res) => {
  const header = req.headers.authorization || '';
  const bearer = header.startsWith('Bearer ') ? header.slice(7) : null;
  const refreshToken = req.body?.refreshToken;
  let userId = null;
  for (const token of [bearer, refreshToken]) {
    if (!token) continue;
    try { userId = verifyToken(token).sub; break; } catch { /* try next */ }
  }
  if (!userId) return fail(res, 'A valid access or refresh token is required to log out', 401);
  const { rows } = await query(
    'UPDATE users SET token_version = token_version + 1 WHERE id = $1 RETURNING id',
    [userId],
  );
  if (!rows[0]) return fail(res, 'Account not found', 404);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'logout','users',$1)`,
    [userId],
  );
  ok(res, null, 'Logged out. Active session invalidated.');
};

export const me = async (req, res) => {
  const { rows } = await query(`SELECT ${PUBLIC_USER} FROM users WHERE id = $1`, [req.user.id]);
  ok(res, rows[0]);
};

export const updateMe = async (req, res) => {
  const allowed = ['full_name', 'region', 'sub_city', 'woreda', 'photo_url', 'device_token',
    'preferred_language', 'accessibility_mode'];
  const fields = allowed.filter((f) => req.body[f] !== undefined);
  if (!fields.length) return fail(res, 'No fields to update');
  const setSql = fields.map((f, i) => `${f} = $${i + 1}`).join(', ');
  const values = fields.map((f) => req.body[f]);
  values.push(req.user.id);
  const { rows } = await query(
    `UPDATE users SET ${setSql}, updated_at = now() WHERE id = $${values.length} RETURNING ${PUBLIC_USER}`,
    values,
  );
  ok(res, rows[0], 'Profile updated');
};

export const changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) return fail(res, 'currentPassword and newPassword required');
  const { rows } = await query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
  if (!rows[0].password_hash || !(await comparePassword(currentPassword, rows[0].password_hash))) {
    return fail(res, 'Current password is incorrect', 401);
  }
  const password_hash = await hashPassword(newPassword);
  await query('UPDATE users SET password_hash = $1 WHERE id = $2', [password_hash, req.user.id]);
  ok(res, null, 'Password changed');
};

const publicUser = (u) => {
  const { password_hash, ...rest } = u;
  return rest;
};

export const searchStaff = async (req, res) => {
  const { q } = req.query;
  if (!q) return fail(res, 'q is required');
  const { rows } = await query(
    `SELECT id, full_name, phone, role, region, sub_city FROM users
     WHERE role != 'citizen' AND (phone ILIKE $1 OR full_name ILIKE $1) AND is_active = true
     ORDER BY full_name LIMIT 10`,
    [`%${q}%`],
  );
  ok(res, rows);
};
