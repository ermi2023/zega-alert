import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { decrypt } from '../utils/crypto.js';

const maskFan = (fanNumber) => `${fanNumber.slice(0, 4)}****${fanNumber.slice(-4)}`;

const presentMockRecord = (record) => ({
  full_name: decrypt(record.full_name),
  phone: decrypt(record.phone),
  fan_number: record.fan_number,
});

const extractFin = (raw) => {
  if (!raw) return null;
  const text = String(raw);
  const keyedMatch = text.match(
    /(?:fin|fan_number|fan|id_number|idNumber|national_id|nationalId)\s*["']?\s*[:=]\s*["']?(\d{16})/i,
  );
  if (keyedMatch) return keyedMatch[1];

  try {
    const parsed = JSON.parse(text);
    const candidate =
      parsed.fin ||
      parsed.FIN ||
      parsed.fan_number ||
      parsed.FAN ||
      parsed.id_number ||
      parsed.idNumber ||
      parsed.national_id ||
      parsed.nationalId;
    if (typeof candidate === 'string' && /^\d{16}$/.test(candidate.trim())) {
      return candidate.trim();
    }
  } catch {
    // QR contents may be plain text rather than JSON.
  }
  const match = text.match(/\b(\d{16})\b/);
  return match ? match[1] : null;
};

const verifyFanNumber = async (req, res, rawFanNumber) => {
  const fanNumber = String(rawFanNumber ?? '').trim();
  if (!/^\d{16}$/.test(fanNumber)) {
    return fail(res, 'Enter a valid 16-digit FAN number.', 422);
  }

  const user = await query(
    'SELECT is_identity_verified FROM users WHERE id = $1',
    [req.user.id],
  );
  if (user.rows[0]?.is_identity_verified) {
    const { rows } = await query(
      `SELECT full_name, phone, fan_number
       FROM fan_verification_records WHERE verified_user_id = $1`,
      [req.user.id],
    );
    return ok(res, {
      status: 'verified',
      verified: true,
      message: 'Your identity is already verified.',
      mock_record: rows[0] ? presentMockRecord(rows[0]) : null,
    });
  }

  const { rows } = await query(
    `WITH claimed AS (
       UPDATE fan_verification_records
       SET verified_user_id = $2, verified_at = now(), updated_at = now()
       WHERE fan_number = $1
         AND is_active = TRUE
         AND (verified_user_id IS NULL OR verified_user_id = $2)
         AND EXISTS (
           SELECT 1 FROM users
           WHERE id = $2 AND is_identity_verified = FALSE
         )
       RETURNING id, full_name, phone, fan_number
     )
     UPDATE users AS u
     SET is_identity_verified = TRUE, updated_at = now()
     FROM claimed
     WHERE u.id = $2
     RETURNING u.id, claimed.full_name, claimed.phone, claimed.fan_number`,
    [fanNumber, req.user.id],
  );

  await query(
    `INSERT INTO audit_log (user_id, action, entity, detail)
     VALUES ($1, 'verify_identity_by_fan', 'users', $2)`,
    [
      req.user.id,
      JSON.stringify({
        fan_number: maskFan(fanNumber),
        matched: rows.length > 0,
      }),
    ],
  );

  if (!rows.length) {
    return ok(res, {
      status: 'not_verified',
      verified: false,
      message: 'This FAN number is not in the active verification records. Check it or contact an administrator.',
      mock_record: null,
    });
  }

  return ok(res, {
    status: 'verified',
    verified: true,
    fan_number: maskFan(fanNumber),
    message: 'Your identity has been verified.',
    mock_record: presentMockRecord(rows[0]),
  });
};

export const submitVerification = (req, res) =>
  verifyFanNumber(req, res, req.body?.fan_number ?? req.body?.id_number);

export const verifyByFan = (req, res) =>
  verifyFanNumber(req, res, req.body?.fan_number);

export const verifyByQr = async (req, res) => {
  const fin = extractFin(req.body?.qr_data);
  if (!fin) return fail(res, 'Could not read a valid 16-digit FAN from the QR code.', 422);
  return verifyFanNumber(req, res, fin);
};

export const getVerificationStatus = async (req, res) => {
  const { rows } = await query(
    `SELECT u.is_identity_verified,
            f.full_name AS record_full_name,
            f.phone AS record_phone,
            f.fan_number AS record_fan_number
     FROM users u
     LEFT JOIN fan_verification_records f ON f.verified_user_id = u.id
     WHERE u.id = $1`,
    [req.user.id],
  );
  if (!rows[0]) return fail(res, 'User not found', 404);

  return ok(res, {
    verified: rows[0].is_identity_verified,
    status: rows[0].is_identity_verified ? 'verified' : 'not_verified',
    verification_source: 'admin_fan_records',
    mock_record: rows[0].record_fan_number
      ? presentMockRecord({
          full_name: rows[0].record_full_name,
          phone: rows[0].record_phone,
          fan_number: rows[0].record_fan_number,
        })
      : null,
  });
};
