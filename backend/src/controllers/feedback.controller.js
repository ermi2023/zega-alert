import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { isUuid } from '../utils/uuid.js';

export const submitFeedback = async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 'Invalid report id', 400);
  const { rating, comment } = req.body;
  const ratingNum = parseInt(rating, 10);
  if (!ratingNum || ratingNum < 1 || ratingNum > 5) return fail(res, 'rating must be 1-5');
  const report = await query(
    `SELECT r.*, u.full_name AS reporter_name FROM reports r
     LEFT JOIN users u ON u.id = r.reporter_id
     WHERE r.id = $1 AND r.reporter_id = $2`,
    [req.params.id, req.user.id],
  );
  if (!report.rows[0]) return fail(res, 'Report not found or not yours', 404);
  if (report.rows[0].status !== 'resolved') {
    return fail(res, 'Feedback is only available once the report is resolved');
  }
  const existing = await query('SELECT id FROM report_feedback WHERE report_id = $1 AND user_id = $2', [
    req.params.id, req.user.id,
  ]);
  if (existing.rows[0]) {
    const { rows } = await query(
      `UPDATE report_feedback SET rating = $1, comment = $2, created_at = now()
       WHERE id = $3 RETURNING *`,
      [ratingNum, comment || null, existing.rows[0].id],
    );
    return ok(res, rows[0], 'Feedback updated');
  }
  const { rows } = await query(
    `INSERT INTO report_feedback (report_id, user_id, rating, comment)
     VALUES ($1,$2,$3,$4) RETURNING *`,
    [req.params.id, req.user.id, ratingNum, comment || null],
  );
  ok(res, rows[0], 'Thanks for your feedback', 201);
};

export const myFeedback = async (req, res) => {
  const { rows } = await query(
    `SELECT f.*, r.title AS report_title FROM report_feedback f
     LEFT JOIN reports r ON r.id = f.report_id
     WHERE f.user_id = $1 ORDER BY f.created_at DESC LIMIT 50`,
    [req.user.id],
  );
  ok(res, rows);
};

export const listFeedback = async (req, res) => {
  const { report_id } = req.query;
  const params = [];
  let whereSql = '';
  if (report_id) { params.push(report_id); whereSql = 'WHERE f.report_id = $1'; }
  const { rows } = await query(
    `SELECT f.*, r.title AS report_title, u.full_name AS user_name
     FROM report_feedback f
     LEFT JOIN reports r ON r.id = f.report_id
     LEFT JOIN users u ON u.id = f.user_id
     ${whereSql} ORDER BY f.created_at DESC LIMIT 200`,
    params,
  );
  ok(res, rows);
};

export const avgRating = async (req, res) => {
  const { rows } = await query(
    `SELECT COUNT(*)::int AS count,
       COALESCE(AVG(rating),0)::numeric(3,2) AS avg_rating,
       COUNT(*) FILTER (WHERE rating = 5)::int AS five,
       COUNT(*) FILTER (WHERE rating = 4)::int AS four,
       COUNT(*) FILTER (WHERE rating = 3)::int AS three,
       COUNT(*) FILTER (WHERE rating = 2)::int AS two,
       COUNT(*) FILTER (WHERE rating = 1)::int AS one
     FROM report_feedback`,
  );
  ok(res, rows[0]);
};
