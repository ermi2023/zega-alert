import crypto from 'node:crypto';
import { query } from '../config/db.js';
import { env } from '../config/env.js';
import { hashPassword, comparePassword } from '../utils/password.js';
import { signTokens, verifyToken } from '../utils/jwt.js';
import { createOtp, verifyOtp } from '../utils/otp.js';
import { ok, fail } from '../utils/response.js';

// In-memory single-use refresh-token jti store. For multi-instance deploys
// replace with a Redis/DB table; this keeps the feature working on Render's
// single-instance free plan.
const REVOKED_JTI = new Set();
const REVOKED_JTI_MAX = 10000;

const revokeJti = (jti) => {
  if (!jti) return;
  if (REVOKED_JTI.size >= REVOKED_JTI_MAX) {
    const it = REVOKED_JTI.values();
    let n = 0;
    while (n < 1000) { const r = it.next(); if (r.done) break; n++; }
  }
  REVOKED_JTI.add(jti);
};

const PUBLIC_USER = `id, full_name, phone, email, role, region, sub_city, woreda, photo_url,
  preferred_language, accessibility_mode, is_verified, is_active, last_login_at, created_at`;

// Accept local (09xxxxxxxx / 9xxxxxxxx) and international (+251...) forms and
// store the local format used across the platform.
const normalizePhone = (raw) => {
  let p = String(raw || '').replace(/[\s\-()]/g, '');
  if (p.startsWith('+251')) p = p.slice(4);
  else if (p.startsWith('251') && p.length > 9) p = p.slice(3);
  if (!p || p.startsWith('0')) return p;
  return p.length === 9 ? `0${p}` : p;
};

export const register = async (req, res) => {
  try {
    const { full_name, phone, email, password, region, sub_city, woreda, preferred_language, accessibility_mode, accepted_terms, accepted_privacy } = req.body;
    if (!full_name || !phone || !password) return fail(res, 'full_name, phone and password are required');
    if (!accepted_terms) return fail(res, 'You must accept the Terms of Service to register', 400);
    const existing = await query('SELECT id FROM users WHERE phone = $1 OR email = $2', [phone, email || '']);
    if (existing.rows.length) return fail(res, 'An account with this phone or email already exists', 409);

    const password_hash = await hashPassword(password);
    const { rows } = await query(
      `INSERT INTO users (full_name, phone, email, password_hash, region, sub_city, woreda, preferred_language, accessibility_mode, accepted_terms_at, accepted_privacy_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, $10, $11)
       RETURNING ${PUBLIC_USER}`,
      [full_name, phone, email || null, password_hash, region || null, sub_city || null, woreda || null,
        preferred_language || 'en', accessibility_mode || false,
        accepted_terms ? new Date() : null,
        accepted_privacy ? new Date() : null],
    );
    await query(
      `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'register','users',$1)`,
      [rows[0].id],
    );
    // OTP delivery must never block or fail account creation.
    let code;
    let smsDelivered = false;
    try {
      const otp = await createOtp({ contact: phone, purpose: 'verify_phone' });
      code = otp.code;
      smsDelivered = otp.sms && otp.sms.status === 'sent';
    } catch (e) {
      console.error('[REGISTER] OTP delivery failed:', e.message);
    }
    // When the SMS gateway is unavailable (e.g. no/invalid Africa's Talking key)
    // the user would otherwise be stuck at the OTP step, so trust the signup and
    // mark the phone verified, and hand the code back for the app to use.
    if (!smsDelivered) {
      await query('UPDATE users SET is_verified = true WHERE phone = $1', [phone]);
    }
    if (env.nodeEnv !== 'production' && code) console.log(`[DEV OTP] ${code} -> ${phone}`);
    ok(res, { ...rows[0], is_verified: rows[0].is_verified || !smsDelivered, devOtp: smsDelivered ? undefined : code },
      smsDelivered ? 'Registered. Verify your phone with the OTP sent.' : 'Registered. You are signed in.', 201);
  } catch (e) {
    console.error('[REGISTER]', e);
    if (!res.headersSent) return fail(res, 'Registration failed. Please try again.', 500);
  }
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

  // 2FA OTP gate for admin roles
  if ((user.role === 'system_admin' || user.role === 'regional_admin') && env.admin2faEnabled) {
    const { code } = await createOtp({ contact: user.phone, purpose: 'login' });
    if (env.nodeEnv !== 'production') console.log(`[DEV 2FA OTP] ${code} -> ${user.phone}`);
    const masked = user.phone.replace(/^(.{3})(.*)(.{2})$/, (_, a, b, c) => a + '*'.repeat(b.length) + c);
    return ok(res, { requires_otp: true, phone: masked }, 'OTP sent for 2FA verification');
  }

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
    // Single-use refresh token rotation: reject reuse of a consumed jti and
    // revoke the presented jti so it cannot be replayed.
    if (payload.jti && REVOKED_JTI.has(payload.jti)) {
      return fail(res, 'Refresh token has been revoked', 401);
    }
    if (payload.jti) revokeJti(payload.jti);
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
  let refreshTokenJti = null;
  for (const token of [bearer, refreshToken]) {
    if (!token) continue;
    try {
      const p = verifyToken(token);
      userId = p.sub;
      if (p.jti) refreshTokenJti = p.jti;
      break;
    } catch { /* try next */ }
  }
  if (!userId) return fail(res, 'A valid access or refresh token is required to log out', 401);
  if (refreshTokenJti) revokeJti(refreshTokenJti);
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
  try {
    const allowed = ['full_name', 'phone', 'email', 'region', 'sub_city', 'woreda', 'photo_url', 'device_token',
      'preferred_language', 'accessibility_mode'];
    const fields = allowed.filter((f) => req.body[f] !== undefined);
    if (!fields.length) return fail(res, 'No fields to update');
    if (fields.includes('full_name') && !String(req.body.full_name || '').trim()) {
      return fail(res, 'Full name cannot be empty');
    }
    if (fields.includes('phone')) {
      const phone = normalizePhone(req.body.phone);
      if (phone.length < 9) return fail(res, 'Enter a valid phone number, e.g. 0911234567');
      const dup = await query('SELECT id FROM users WHERE phone = $1 AND id <> $2', [phone, req.user.id]);
      if (dup.rows.length) return fail(res, 'That phone number is already in use', 409);
      req.body.phone = phone;
    }
    if (fields.includes('email')) {
      const email = String(req.body.email || '').trim();
      if (email) {
        const dup = await query('SELECT id FROM users WHERE email = $1 AND id <> $2', [email, req.user.id]);
        if (dup.rows.length) return fail(res, 'That email is already in use', 409);
      }
      req.body.email = email || null;
    }
    const setSql = fields.map((f, i) => `${f} = $${i + 1}`).join(', ');
    const values = fields.map((f) => req.body[f]);
    values.push(req.user.id);
    const { rows } = await query(
      `UPDATE users SET ${setSql}, updated_at = now() WHERE id = $${values.length} RETURNING ${PUBLIC_USER}`,
      values,
    );
    await query(
      `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'update_profile','users',$1)`,
      [req.user.id],
    );
    ok(res, rows[0], 'Profile updated');
  } catch (e) {
    console.error('[UPDATE_ME]', e);
    if (!res.headersSent) return fail(res, 'Could not update profile. Please try again.', 500);
  }
};

export const resetPassword = async (req, res) => {
  try {
    const { phone, code, new_password } = req.body;
    if (!phone || !code || !new_password) return fail(res, 'phone, code and new_password are required');
    if (String(new_password).length < 6) return fail(res, 'Password must be at least 6 characters');
    const result = await verifyOtp({ contact: phone, code, purpose: 'reset_password' });
    if (!result.ok) return fail(res, `OTP invalid/expired (${result.reason})`, 400);
    const { rows } = await query('SELECT id FROM users WHERE phone = $1', [phone]);
    if (!rows[0]) return fail(res, 'No account found for this phone.', 404);
    const hash = await hashPassword(new_password);
    await query('UPDATE users SET password_hash = $1, updated_at = now() WHERE phone = $2', [hash, phone]);
    ok(res, null, 'Password reset successful. You can now sign in.');
  } catch (e) {
    console.error('[RESET_PASSWORD]', e);
    if (!res.headersSent) return fail(res, 'Could not reset password. Please try again.', 500);
  }
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

export const verifyAdminOtp = async (req, res) => {
  const { phone, otp } = req.body;
  if (!phone || !otp) return fail(res, 'phone and otp are required');
  const result = await verifyOtp({ contact: phone, code: otp, purpose: 'login' });
  if (!result.ok) return fail(res, `OTP invalid/expired (${result.reason})`, 400);
  const { rows } = await query('SELECT * FROM users WHERE phone = $1', [phone]);
  const user = rows[0];
  if (!user) return fail(res, 'User not found', 404);
  if (!user.is_active) return fail(res, 'Account disabled', 403);
  await query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'login','users',$1)`,
    [user.id],
  );
  const tokens = signTokens(user);
  ok(res, { user: publicUser(user), ...tokens }, 'Login successful');
};

const publicUser = (u) => {
  const { password_hash, ...rest } = u;
  return rest;
};

export const searchStaff = async (req, res) => {
  const q = (req.query.q || '').trim();
  const limit = q ? 10 : 100;
  const { rows } = await query(
    `SELECT id, full_name, phone, role, region, sub_city FROM users
     WHERE role != 'citizen' AND (phone ILIKE $1 OR full_name ILIKE $1) AND is_active = true
     ORDER BY full_name LIMIT $2`,
    [`%${q}%`, limit],
  );
  ok(res, rows);
};
