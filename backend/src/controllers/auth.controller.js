import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { query } from '../config/db.js';
import { env } from '../config/env.js';
import { hashPassword, comparePassword } from '../utils/password.js';
import { signTokens, verifyToken } from '../utils/jwt.js';
import { createOtp, verifyOtp } from '../utils/otp.js';
import { ok, fail } from '../utils/response.js';
import { writeAudit } from '../utils/audit.js';
import { getSecurityPolicy, validatePassword, accessTokenExpiry } from '../services/security-policy.service.js';

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

const issueTokens = (user, policy) =>
  signTokens(user, { accessExpiresIn: accessTokenExpiry(policy) });

const recordFailedLogin = async (user, policy) => {
  if (!user) return;
  const attempts = (user.failed_login_attempts || 0) + 1;
  const locked = attempts >= (policy.max_login_attempts || 5);
  await query(
    `UPDATE users SET failed_login_attempts = $1,
       locked_until = CASE WHEN $2 THEN now() + ($3 || ' minutes')::interval ELSE locked_until END
     WHERE id = $4`,
    [attempts, locked, String(policy.lockout_duration_minutes || 30), user.id],
  ).catch(() => {});
};

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

    const policy = await getSecurityPolicy();
    const passwordError = validatePassword(password, policy);
    if (passwordError) return fail(res, passwordError, 400);
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
    // In development, the app receives a fallback code when SMS delivery is unavailable.
    if (!smsDelivered && env.nodeEnv !== 'production') {
      await query('UPDATE users SET is_verified = true WHERE phone = $1', [phone]);
    }
    const developmentFallback = env.nodeEnv !== 'production' && !smsDelivered;
    ok(res, {
      ...rows[0],
      is_verified: rows[0].is_verified || developmentFallback,
      devOtp: developmentFallback ? code : undefined,
    },
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
  try {
    const { code, sms } = await createOtp({ contact, purpose });
    const delivered = sms?.status === 'sent';
    if (env.nodeEnv === 'production' && !delivered) {
      await query(
        `UPDATE otp_codes SET used_at = now()
         WHERE contact = $1 AND purpose = $2 AND code = $3 AND used_at IS NULL`,
        [contact, purpose, crypto.createHmac('sha256', env.jwtSecret).update(code).digest('hex')],
      );
      return fail(res, 'Verification delivery is unavailable. Please try again later.', 503);
    }
    const devOtp = !delivered ? code : undefined;
    ok(res, devOtp ? { devOtp } : null, delivered ? 'OTP sent.' : 'Development OTP generated.');
  } catch (e) {
    if (e.statusCode === 429) return fail(res, e.message, 429);
    console.error('[REQUEST_OTP]', e);
    if (!res.headersSent) return fail(res, 'Could not send verification code. Please try again.', 500);
  }
};

export const verifyOtpEndpoint = async (req, res) => {
  const { contact, code, purpose = 'verify_phone' } = req.body;
  const result = await verifyOtp({ contact, code, purpose });
  if (!result.ok) return fail(res, `OTP invalid/expired (${result.reason})`, 400);
  if (purpose === 'reset_password') {
    const { rows } = await query(
      'SELECT id, token_version FROM users WHERE phone = $1',
      [contact],
    );
    if (!rows[0]) return fail(res, 'No account found for this phone.', 404);
    const resetToken = jwt.sign(
      {
        type: 'password_reset',
        sub: rows[0].id,
        ver: rows[0].token_version ?? 0,
      },
      env.jwtSecret,
      { expiresIn: '10m' },
    );
    return ok(res, { resetToken }, 'Phone number verified.');
  }
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
  const policy = await getSecurityPolicy();
  if (user?.locked_until && new Date(user.locked_until) > new Date()) {
    return fail(res, 'Account temporarily locked after repeated failed attempts. Try again later.', 423);
  }
  if (!user || !user.password_hash || !(await comparePassword(password, user.password_hash))) {
    await recordFailedLogin(user, policy);
    return fail(res, 'Invalid credentials', 401);
  }
  if (!user.is_active) return fail(res, 'Account disabled', 403);

  // 2FA OTP gate for admin roles
  if ((user.role === 'system_admin' || user.role === 'regional_admin') && env.admin2faEnabled) {
    await createOtp({ contact: user.phone, purpose: 'login' });
    const masked = user.phone.replace(/^(.{3})(.*)(.{2})$/, (_, a, b, c) => a + '*'.repeat(b.length) + c);
    return ok(res, { requires_otp: true, phone: masked }, 'OTP sent for 2FA verification');
  }

  await query(
    `UPDATE users SET last_login_at = now(), failed_login_attempts = 0, locked_until = NULL WHERE id = $1`,
    [user.id],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'login','users',$1)`,
    [user.id],
  );
  const tokens = issueTokens(user, policy);
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
  const policy = await getSecurityPolicy();
  await query(
    `UPDATE users SET last_login_at = now(), failed_login_attempts = 0, locked_until = NULL WHERE id = $1`,
    [user.id],
  );
  // Audit: OTP-based login was previously unaudited (spec §8.3 — record all login paths).
  await writeAudit({
    userId: user.id,
    action: 'login',
    entity: 'users',
    entityId: user.id,
    detail: { method: 'otp' },
    req,
  });
  const tokens = issueTokens(user, policy);
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
    const policy = await getSecurityPolicy();
    ok(res, issueTokens(rows[0], policy), 'Tokens refreshed');
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
    const { reset_token, phone, code, new_password } = req.body;
    if (!new_password) return fail(res, 'new_password is required');
    const policy = await getSecurityPolicy();
    const passwordError = validatePassword(new_password, policy);
    if (passwordError) return fail(res, passwordError, 400);

    let user;
    let expectedVersion;
    if (reset_token) {
      let payload;
      try {
        payload = jwt.verify(reset_token, env.jwtSecret);
      } catch {
        return fail(res, 'Password reset verification expired. Request a new code.', 401);
      }
      if (payload.type !== 'password_reset' || !payload.sub) {
        return fail(res, 'Password reset verification is invalid.', 401);
      }
      expectedVersion = payload.ver ?? 0;
      const { rows } = await query(
        'SELECT id, token_version FROM users WHERE id = $1',
        [payload.sub],
      );
      user = rows[0];
      if (!user || (user.token_version ?? 0) !== expectedVersion) {
        return fail(res, 'Password reset verification is no longer valid.', 401);
      }
    } else {
      if (!phone || !code) return fail(res, 'phone, code and new_password are required');
      const result = await verifyOtp({ contact: phone, code, purpose: 'reset_password' });
      if (!result.ok) return fail(res, `OTP invalid/expired (${result.reason})`, 400);
      const { rows } = await query('SELECT id, token_version FROM users WHERE phone = $1', [phone]);
      user = rows[0];
      if (!user) return fail(res, 'No account found for this phone.', 404);
      expectedVersion = user.token_version ?? 0;
    }

    const hash = await hashPassword(new_password);
    const { rows: updated } = await query(
      `UPDATE users
       SET password_hash = $1, failed_login_attempts = 0, locked_until = NULL,
           updated_at = now(), token_version = token_version + 1
       WHERE id = $2 AND token_version = $3
       RETURNING id`,
      [hash, user.id, expectedVersion],
    );
    if (!updated.length) return fail(res, 'Password reset verification is no longer valid.', 401);
    // Audit: password reset via OTP is security-sensitive (spec §8.3 + business rule §14.7).
    await writeAudit({
      userId: user.id,
      action: 'reset_password',
      entity: 'users',
      entityId: user.id,
      detail: { method: reset_token ? 'reset_token' : 'otp' },
      req,
    });
    ok(res, null, 'Password reset successful. You can now sign in.');
  } catch (e) {
    console.error('[RESET_PASSWORD]', e);
    if (!res.headersSent) return fail(res, 'Could not reset password. Please try again.', 500);
  }
};

export const changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) return fail(res, 'currentPassword and newPassword required');
  if (String(newPassword).length < 8) return fail(res, 'Password must be at least 8 characters');
  const { rows } = await query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
  if (!rows[0].password_hash || !(await comparePassword(currentPassword, rows[0].password_hash))) {
    return fail(res, 'Current password is incorrect', 401);
  }
  const policy = await getSecurityPolicy();
  const passwordError = validatePassword(newPassword, policy);
  if (passwordError) return fail(res, passwordError, 400);
  const password_hash = await hashPassword(newPassword);
  await query('UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2', [password_hash, req.user.id]);
  // Audit: password change by an authenticated user (spec §8.3 + business rule §14.7).
  await writeAudit({
    userId: req.user.id,
    action: 'change_password',
    entity: 'users',
    entityId: req.user.id,
    detail: { method: 'self' },
    req,
  });
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
  const policy = await getSecurityPolicy();
  await query(
    `UPDATE users SET last_login_at = now(), failed_login_attempts = 0, locked_until = NULL WHERE id = $1`,
    [user.id],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1,'login','users',$1)`,
    [user.id],
  );
  const tokens = issueTokens(user, policy);
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
