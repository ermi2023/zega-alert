import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { isUuid } from '../utils/uuid.js';
import { resolveAddress } from '../services/geocode.service.js';
import { encrypt, decrypt } from '../utils/crypto.js';

const REPORT_COLS = `r.id, r.reporter_id, r.category, r.severity, r.status, r.title, r.description,
  r.latitude, r.longitude, r.address_text, r.region, r.sub_city, r.woreda, r.is_anonymous,
  r.evidence, r.assigned_to, r.priority_score, r.incident_at, r.reported_at, r.updated_at, r.resolved_at,
  u.full_name AS reporter_name`;

// address_text is PII and stored AES-256-GCM encrypted at rest.
const decryptRow = (row) => (row ? { ...row, address_text: decrypt(row.address_text) } : row);

async function syncEvidence(reportId, evidence) {
  if (!Array.isArray(evidence)) return;
  for (const item of evidence) {
    if (item && (item.value || item.url)) {
      await query(
        `INSERT INTO media_attachments (report_id, file_url, file_type) VALUES ($1, $2, $3)`,
        [reportId, item.value || item.url, item.type || 'image'],
      ).catch(() => {});
    }
  }
}

export const createReport = async (req, res) => {
  const {
    category, severity, title, description, latitude, longitude, address_text,
    region, sub_city, woreda, is_anonymous, evidence, incident_at, status,
  } = req.body;
  if (!category || !title) return fail(res, 'category and title are required');
  const isDraft = status === 'draft';
  const resolvedAddress = await resolveAddress({ latitude, longitude, address_text });
  const { rows } = await query(
    `INSERT INTO reports (reporter_id, category, severity, status, title, description, latitude, longitude,
       address_text, region, sub_city, woreda, is_anonymous, evidence, incident_at, priority_score)
     VALUES ($1,$2,$3,$4::report_status,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
     RETURNING *`,
    [req.user.id, category, severity || 'medium', isDraft ? 'draft' : 'pending', title, description || null,
      latitude || null, longitude || null, encrypt(resolvedAddress), region || null,
      sub_city || null, woreda || null, is_anonymous || false,
      evidence ? JSON.stringify(evidence) : '[]', incident_at || null,
      priorityScore(severity, category)],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,'create_report','reports',$2,$3)`,
    [req.user.id, rows[0].id, JSON.stringify({ category, severity: severity || 'medium', status: rows[0].status })],
  );
  await query(
    `INSERT INTO status_history (report_id, status, notes, changed_by) VALUES ($1,$2,$3,$4)`,
    [rows[0].id, rows[0].status, isDraft ? 'Draft saved by citizen' : 'Report submitted by citizen', req.user.id],
  );

  // Sync uploaded evidence into media_attachments table (Figure 24 / Doc 4.8.1)
  await syncEvidence(rows[0].id, evidence);

  ok(res, decryptRow(rows[0]), isDraft ? 'Draft saved' : 'Report submitted', 201);
};

export const listReports = async (req, res) => {
  const { status, region, sub_city, category, q, page = 1, limit = 20 } = req.query;
  const where = [];
  const params = [];
  if (status) { params.push(status); where.push(`r.status = $${params.length}`); }
  if (region) { params.push(region); where.push(`r.region = $${params.length}`); }
  if (sub_city) { params.push(sub_city); where.push(`r.sub_city = $${params.length}`); }
  if (category) { params.push(category); where.push(`r.category = $${params.length}`); }
  if (q) { params.push(`%${q}%`); where.push(`(r.title ILIKE $${params.length} OR r.description ILIKE $${params.length})`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  params.push(parseInt(limit, 10), (parseInt(page, 10) - 1) * parseInt(limit, 10));
  const { rows } = await query(
    `SELECT ${REPORT_COLS} FROM reports r
     LEFT JOIN users u ON u.id = r.reporter_id
     ${whereSql}
     ORDER BY r.priority_score DESC, r.reported_at DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  const total = await query(`SELECT COUNT(*)::int AS n FROM reports r ${whereSql}`, params.slice(0, -2));
  ok(res, { items: rows.map(decryptRow), total: total.rows[0].n, page: +page, limit: +limit });
};

export const getReport = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid report id', 400);
  const { rows } = await query(
    `SELECT ${REPORT_COLS} FROM reports r LEFT JOIN users u ON u.id = r.reporter_id WHERE r.id = $1`,
    [req.params.id],
  );
  if (!rows[0]) return fail(res, 'Report not found', 404);
  const history = await query(
    `SELECT h.*, u.full_name AS changed_by_name FROM status_history h
     LEFT JOIN users u ON u.id = h.changed_by WHERE h.report_id = $1 ORDER BY h.created_at ASC`,
    [req.params.id],
  );
  rows[0] = decryptRow(rows[0]);
  rows[0].history = history.rows;
  ok(res, rows[0]);
};

export const updateReportStatus = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid report id', 400);
  const { status, assigned_to, response_notes, notes } = req.body;
  const valid = ['draft', 'submitted', 'pending', 'under_review', 'assigned', 'in_progress', 'verified', 'rejected', 'resolved', 'closed'];
  if (!valid.includes(status)) return fail(res, `status must be one of ${valid.join(', ')}`);
  const investigationNotes = response_notes ?? notes ?? null;
  const { rows } = await query(
    `UPDATE reports SET status = $1::report_status, assigned_to = COALESCE($2, assigned_to), updated_at = now(),
       resolved_at = CASE WHEN $1::text IN ('resolved','closed') THEN now() ELSE resolved_at END
     WHERE id = $3 RETURNING *`,
    [status, assigned_to || null, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Report not found', 404);
  await query(
    `INSERT INTO status_history (report_id, status, notes, changed_by) VALUES ($1,$2,$3,$4)`,
    [rows[0].id, status, investigationNotes, req.user.id],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,'update_report_status','reports',$2,$3)`,
    [req.user.id, rows[0].id, JSON.stringify({ status, assigned_to, response_notes: investigationNotes })],
  );
  ok(res, decryptRow(rows[0]), 'Report updated');
};

/**
 * Update a citizen-owned report (used for drafts and for editing a report that
 * has not yet been picked up by staff). Staff changes go through the status
 * endpoint above.
 */
export const updateOwnReport = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid report id', 400);
  const { rows: existingRows } = await query('SELECT * FROM reports WHERE id = $1', [req.params.id]);
  const existing = existingRows[0];
  if (!existing) return fail(res, 'Report not found', 404);
  if (existing.reporter_id !== req.user.id) return fail(res, 'Not your report', 403);
  if (!['draft', 'pending', 'submitted'].includes(existing.status)) {
    return fail(res, 'This report can no longer be edited', 400);
  }

  const {
    category, severity, title, description, latitude, longitude, address_text,
    region, sub_city, woreda, is_anonymous, evidence, incident_at, status,
  } = req.body;
  const nextStatus = status === 'draft' ? 'draft' : status === 'pending' ? 'pending' : existing.status;
  const hasAddressInput = latitude != null || longitude != null || address_text != null;
  const resolvedAddress = hasAddressInput
    ? await resolveAddress({
      latitude: latitude ?? existing.latitude,
      longitude: longitude ?? existing.longitude,
      address_text: address_text ?? decrypt(existing.address_text),
    })
    : decrypt(existing.address_text);
  const mergedEvidence = Array.isArray(evidence) ? evidence : existing.evidence;

  const { rows } = await query(
    `UPDATE reports SET
       category = COALESCE($1, category),
       severity = COALESCE($2::report_severity, severity),
       status = $3::report_status,
       title = COALESCE($4, title),
       description = COALESCE($5, description),
       latitude = COALESCE($6, latitude),
       longitude = COALESCE($7, longitude),
       address_text = $8,
       region = COALESCE($9, region),
       sub_city = COALESCE($10, sub_city),
       woreda = COALESCE($11, woreda),
       is_anonymous = COALESCE($12, is_anonymous),
       evidence = $13,
       incident_at = COALESCE($14, incident_at),
       priority_score = CASE WHEN $2::text IS NOT NULL THEN $15 ELSE priority_score END,
       updated_at = now()
     WHERE id = $16 RETURNING *`,
    [category || null, severity || null, nextStatus, title || null, description || null,
      latitude ?? null, longitude ?? null, encrypt(resolvedAddress), region || null,
      sub_city || null, woreda || null, is_anonymous ?? null,
      JSON.stringify(mergedEvidence || []), incident_at || null,
      priorityScore(severity || existing.severity, category || existing.category), req.params.id],
  );
  await query(
    `INSERT INTO status_history (report_id, status, notes, changed_by) VALUES ($1,$2,$3,$4)`,
    [req.params.id, nextStatus,
      nextStatus === 'draft' ? 'Draft updated' : 'Report updated and submitted by citizen', req.user.id],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,'update_report','reports',$2,$3)`,
    [req.user.id, req.params.id, JSON.stringify({ status: nextStatus })],
  );
  if (Array.isArray(evidence)) await syncEvidence(req.params.id, evidence);
  ok(res, decryptRow(rows[0]), nextStatus === 'draft' ? 'Draft saved' : 'Report submitted');
};

export const addReportEvidence = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid report id', 400);
  const { rows: existingRows } = await query('SELECT * FROM reports WHERE id = $1', [req.params.id]);
  const existing = existingRows[0];
  if (!existing) return fail(res, 'Report not found', 404);
  const isStaff = req.user.role !== 'citizen';
  if (!isStaff && existing.reporter_id !== req.user.id) return fail(res, 'Not your report', 403);
  if (['resolved', 'closed', 'rejected'].includes(existing.status)) {
    return fail(res, 'Evidence can no longer be added to this report', 400);
  }
  const { type, value, url } = req.body;
  const fileUrl = value || url;
  if (!fileUrl) return fail(res, 'value or url is required');
  const item = { type: type || 'image', value: fileUrl, added_at: new Date().toISOString() };
  const evidence = Array.isArray(existing.evidence) ? existing.evidence : [];
  evidence.push(item);
  const { rows } = await query(
    'UPDATE reports SET evidence = $1, updated_at = now() WHERE id = $2 RETURNING *',
    [JSON.stringify(evidence), req.params.id],
  );
  await syncEvidence(req.params.id, [item]);
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,'add_report_evidence','reports',$2,$3)`,
    [req.user.id, req.params.id, JSON.stringify({ type: item.type })],
  );
  ok(res, decryptRow(rows[0]), 'Evidence attached');
};

export const getReportHistory = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid report id', 400);
  const { rows } = await query(
    `SELECT h.*, u.full_name AS changed_by_name FROM status_history h
     LEFT JOIN users u ON u.id = h.changed_by WHERE h.report_id = $1 ORDER BY h.created_at ASC`,
    [req.params.id],
  );
  ok(res, rows);
};

export const myReports = async (req, res) => {
  const { rows } = await query(
    `SELECT ${REPORT_COLS} FROM reports r LEFT JOIN users u ON u.id = r.reporter_id WHERE r.reporter_id = $1 ORDER BY r.reported_at DESC`,
    [req.user.id],
  );
  ok(res, rows.map(decryptRow));
};

const priorityScore = (severity, category) => {
  const sev = { critical: 100, high: 70, medium: 40, low: 10 }[severity] || 40;
  const catBonus = ['robbery', 'assault', 'kidnapping', 'murder', 'rape', 'kidnap'].includes(String(category).toLowerCase()) ? 30 : 0;
  return sev + catBonus;
};
