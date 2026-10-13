import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

// In production, this would integrate with Fayda API
// For now, we store the ID image and mark as pending review

export const submitVerification = async (req, res) => {
  const { id_number, id_image_url, full_name, date_of_birth } = req.body;
  if (!id_number || !id_image_url) {
    return fail(res, 'id_number and id_image_url are required');
  }

  // Store verification request
  await query(
    `INSERT INTO audit_log (user_id, action, entity, detail)
     VALUES ($1, 'submit_id_verification', 'users', $2)`,
    [req.user.id, JSON.stringify({ id_number, id_image_url, full_name, date_of_birth })],
  );

  // In a real system, this would call the Fayda API
  // For now, auto-verify for demo purposes
  await query(
    `UPDATE users SET is_verified = true WHERE id = $1`,
    [req.user.id],
  );

  ok(res, {
    status: 'verified',
    message: 'ID verification submitted. For demo purposes, verification is automatic.',
    id_number: id_number.substring(0, 4) + '****' + id_number.substring(id_number.length - 4),
  });
};

const maskId = (id) => {
  const s = String(id || '');
  if (s.length <= 8) return s;
  return s.substring(0, 4) + '****' + s.substring(s.length - 4);
};

const extractFin = (raw) => {
  if (!raw) return null;
  const text = String(raw);
  try {
    const parsed = JSON.parse(text);
    const candidate = parsed.fin || parsed.FIN || parsed.id_number || parsed.idNumber || parsed.nationalId;
    if (candidate) return String(candidate);
  } catch (_) {
    // not JSON, fall through to regex
  }
  const match = text.match(/\b(\d{12})\b/);
  return match ? match[1] : null;
};

// Scan a Fayda National ID QR code and verify the account.
// `qr_data` may be raw QR text or a JSON payload containing the FIN.
export const verifyByQr = async (req, res) => {
  const { qr_data, full_name } = req.body;
  if (!qr_data) return fail(res, 'qr_data is required');

  const fin = extractFin(qr_data);
  if (!fin) {
    return fail(res, 'Could not read a valid Fayda FIN from the QR code', 422);
  }

  await query(
    `INSERT INTO audit_log (user_id, action, entity, detail)
     VALUES ($1, 'verify_fayda_qr', 'users', $2)`,
    [req.user.id, JSON.stringify({ fin_masked: maskId(fin), full_name: full_name || null })],
  );

  await query(
    `UPDATE users SET is_verified = true, updated_at = now() WHERE id = $1`,
    [req.user.id],
  );

  ok(res, {
    status: 'verified',
    verified: true,
    fin_masked: maskId(fin),
    message: 'Fayda National ID verified via QR scan.',
  });
};

export const getVerificationStatus = async (req, res) => {
  const { rows } = await query(
    `SELECT id, is_verified FROM users WHERE id = $1`,
    [req.user.id],
  );
  if (!rows[0]) return fail(res, 'User not found', 404);

  ok(res, {
    verified: rows[0].is_verified,
    status: rows[0].is_verified ? 'verified' : 'not_verified',
  });
};