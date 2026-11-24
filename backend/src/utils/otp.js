import crypto from 'crypto';
import { query } from '../config/db.js';
import { sendOtpSms } from '../services/sms.service.js';
import { env } from '../config/env.js';

export const generateCode = () => crypto.randomInt(100000, 1000000).toString();

const hashCode = (code) =>
  crypto.createHmac('sha256', env.jwtSecret).update(String(code)).digest('hex');

export const createOtp = async ({ contact, purpose, ttlMinutes = 10 }) => {
  const { rows: recent } = await query(
    `SELECT MAX(created_at) AS latest, COUNT(*)::INTEGER AS count
     FROM otp_codes
     WHERE contact = $1 AND purpose = $2
       AND created_at > now() - INTERVAL '1 hour'`,
    [contact, purpose],
  );
  const lastCreated = recent[0]?.latest;
  if (lastCreated && Date.now() - new Date(lastCreated).getTime() < 60_000) {
    const error = new Error('Please wait before requesting another verification code.');
    error.statusCode = 429;
    throw error;
  }
  if (Number(recent[0]?.count || 0) >= 5) {
    const error = new Error('Too many verification codes requested. Try again later.');
    error.statusCode = 429;
    throw error;
  }

  const code = generateCode();
  const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);
  await query(
    `INSERT INTO otp_codes (contact, code, purpose, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [contact, hashCode(code), purpose, expiresAt],
  );
  const sms = await sendOtpSms(contact, code);
  return { code, sms };
};

export const verifyOtp = async ({ contact, code, purpose }) => {
  const { rows } = await query(
    `SELECT * FROM otp_codes
     WHERE contact = $1 AND purpose = $2 AND used_at IS NULL
     ORDER BY created_at DESC LIMIT 1`,
    [contact, purpose],
  );
  const otp = rows[0];
  if (!otp) return { ok: false, reason: 'INVALID' };
  if (new Date(otp.expires_at) < new Date()) return { ok: false, reason: 'EXPIRED' };
  if (otp.attempts >= 5) return { ok: false, reason: 'LIMIT' };
  const { rows: updated } = await query(
    `UPDATE otp_codes
     SET attempts = attempts + 1
     WHERE id = $1 AND used_at IS NULL AND attempts < 5
     RETURNING attempts`,
    [otp.id],
  );
  if (!updated.length) return { ok: false, reason: 'LIMIT' };

  const stored = String(otp.code || '');
  const supplied = hashCode(code);
  const valid = stored.length === supplied.length &&
    crypto.timingSafeEqual(Buffer.from(stored), Buffer.from(supplied));
  if (!valid) return { ok: false, reason: 'INVALID' };

  const { rows: consumed } = await query(
    'UPDATE otp_codes SET used_at = now() WHERE id = $1 AND used_at IS NULL RETURNING id',
    [otp.id],
  );
  if (!consumed.length) return { ok: false, reason: 'INVALID' };
  return { ok: true, otp };
};
