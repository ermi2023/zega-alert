import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { isUuid } from '../utils/uuid.js';
import { resolveAddress } from '../services/geocode.service.js';

const REPORT_COLS = `r.id, r.reporter_id, r.category, r.severity, r.status, r.title, r.description,
  r.latitude, r.longitude, r.address_text, r.region, r.sub_city, r.woreda, r.is_anonymous,
  r.evidence, r.assigned_to, r.priority_score, r.reported_at, r.updated_at, r.resolved_at,
  u.full_name AS reporter_name`;

export const createReport = async (req, res) => {
  const {
    category, severity, title, description, latitude, longitude, address_text,
    region, sub_city, woreda, is_anonymous, evidence,
  } = req.body;
  if (!category || !title) return fail(res, 'category and title are required');
  const resolvedAddress = await resolveAddress({ latitude, longitude, address_text });
  const { rows } = await query(
    `INSERT INTO reports (reporter_id, category, severity, title, description, latitude, longitude,
       address_text, region, sub_city, woreda, is_anonymous, evidence, priority_score)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
     RETURNING *`,
    [req.user.id, category, severity || 'medium', title, description || null,
      latitude || null, longitude || null, resolvedAddress || null, region || null,
      sub_city || null, woreda || null, is_anonymous || false,
      evidence ? JSON.stringify(evidence) : '[]', priorityScore(severity, category)],
  );
  await query(
    `INSERT INTO audit_log (user_id, action, entity, entity_id, detail) VALUES ($1,'create_report','reports',$2,$3)`,
    [req.user.id, rows[0].id, JSON.stringify({ category, severity: severity || 'medium' })],
  );

  // Sync to media_attachments table (Figure 24 / Doc 4.8.1)
  if (Array.isArray(evidence) && evidence.length > 0) {
    for (const item of evidence) {
      if (item && (item.value || item.url)) {
        await query(
          `INSERT INTO media_attachments (report_id, file_url, file_type) VALUES ($1, $2, $3)`,
          [rows[0].id, item.value || item.url, item.type || 'image'],
        ).catch(() => {});
      }
    }
  }

  ok(res, rows[0], 'Report submitted', 201);
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
  ok(res, { items: rows, total: total.rows[0].n, page: +page, limit: +limit });
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
  ok(res, rows[0], 'Report updated');
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
  ok(res, rows);
};

const priorityScore = (severity, category) => {
  const sev = { critical: 100, high: 70, medium: 40, low: 10 }[severity] || 40;
  const catBonus = ['robbery', 'assault', 'kidnapping', 'murder', 'rape', 'kidnap'].includes(String(category).toLowerCase()) ? 30 : 0;
  return sev + catBonus;
};
