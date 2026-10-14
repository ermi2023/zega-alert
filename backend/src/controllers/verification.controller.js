import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { verifyFin, faydaEnabled, maskId } from '../services/fayda.service.js';

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

// Manual ID submission (photo + number). Verifies against the Fayda National ID
// service when configured; otherwise records the request for review.
export const submitVerification = async (req, res) => {
  const { id_number, id_image_url, full_name, date_of_birth } = req.body;
  if (!id_number || !id_image_url) {
    return fail(res, 'id_number and id_image_url are required');
  }

  const result = await verifyFin(String(id_number), { fullName: full_name, dateOfBirth: date_of_birth });

  await query(
    `INSERT INTO audit_log (user_id, action, entity, detail)
     VALUES ($1, 'submit_id_verification', 'users', $2)`,
    [req.user.id, JSON.stringify({ id_number: maskId(id_number), id_image_url, full_name, fayda_status: result.status })],
  );

  if (result.status === 'error') {
    return fail(res, result.error || 'Fayda verification failed', 502);
  }

  if (result.verified) {
    await query(`UPDATE users SET is_verified = true, updated_at = now() WHERE id = $1`, [req.user.id]);
    return ok(res, {
      status: 'verified',
      verified: true,
      message: faydaEnabled()
        ? 'Fayda National ID verified.'
        : 'ID verification submitted. Development mode: verification is automatic.',
      id_number: maskId(id_number),
    });
  }

  ok(res, {
    status: 'rejected',
    verified: false,
    message: 'Fayda National ID could not be verified.',
    id_number: maskId(id_number),
  });
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

  const result = await verifyFin(fin, { fullName: full_name });

  await query(
    `INSERT INTO audit_log (user_id, action, entity, detail)
     VALUES ($1, 'verify_fayda_qr', 'users', $2)`,
    [req.user.id, JSON.stringify({ fin_masked: maskId(fin), full_name: full_name || null, fayda_status: result.status })],
  );

  if (result.status === 'error') {
    return fail(res, result.error || 'Fayda verification failed', 502);
  }

  if (!result.verified) {
    return ok(res, {
      status: 'rejected',
      verified: false,
      fin_masked: maskId(fin),
      message: 'Fayda National ID could not be verified.',
    });
  }

  await query(
    `UPDATE users SET is_verified = true, updated_at = now() WHERE id = $1`,
    [req.user.id],
  );

  ok(res, {
    status: 'verified',
    verified: true,
    fin_masked: maskId(fin),
    message: faydaEnabled()
      ? 'Fayda National ID verified via QR scan.'
      : 'Fayda National ID verified via QR scan (development mode).',
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
    fayda_configured: faydaEnabled(),
  });
};
