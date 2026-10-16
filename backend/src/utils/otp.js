import crypto from 'crypto';
import { query } from '../config/db.js';
import { sendOtpSms } from '../services/sms.service.js';

export const generateCode = () => crypto.randomInt(100000, 1000000).toString();

export const createOtp = async ({ contact, purpose, ttlMinutes = 10 }) => {
  const code = generateCode();
  const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);
  await query(
    `INSERT INTO otp_codes (contact, code, purpose, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [contact, code, purpose, expiresAt],
  );
  const sms = await sendOtpSms(contact, code);
  return { code, sms };
};

export const verifyOtp = async ({ contact, code, purpose }) => {
  const { rows } = await query(
    `SELECT * FROM otp_codes
     WHERE contact = $1 AND code = $2 AND purpose = $3 AND used_at IS NULL
     ORDER BY created_at DESC LIMIT 1`,
    [contact, code, purpose],
  );
  const otp = rows[0];
  if (!otp) return { ok: false, reason: 'INVALID' };
  if (new Date(otp.expires_at) < new Date()) return { ok: false, reason: 'EXPIRED' };
  if (otp.attempts >= 5) return { ok: false, reason: 'LIMIT' };
  await query('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1', [otp.id]);
  await query('UPDATE otp_codes SET used_at = now() WHERE id = $1', [otp.id]);
  return { ok: true, otp };
};
