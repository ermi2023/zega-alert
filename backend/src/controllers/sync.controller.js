import { query } from '../config/db.js';
import { ok } from '../utils/response.js';

// Returns records updated since a given timestamp for offline clients.
export const sync = async (req, res) => {
  const since = req.query.since ? new Date(req.query.since) : new Date(0);
  if (isNaN(since.getTime())) return res.status(400).json({ success: false, message: 'Invalid since timestamp' });

  const [announcements, reports, missing, wanted, legal] = await Promise.all([
    query(`SELECT * FROM announcements WHERE updated_at > $1 OR published_at > $1 ORDER BY COALESCE(updated_at, published_at) ASC`, [since]),
    query(`SELECT * FROM reports WHERE reported_at > $1 OR resolved_at > $1 ORDER BY reported_at ASC`, [since]),
    query(`SELECT * FROM missing_persons WHERE created_at > $1 OR updated_at > $1 ORDER BY created_at ASC`, [since]),
    query(`SELECT * FROM wanted_persons WHERE created_at > $1 OR updated_at > $1 ORDER BY created_at ASC`, [since]),
    query(`SELECT * FROM legal_content WHERE created_at > $1 OR updated_at > $1 ORDER BY created_at ASC`, [since]),
  ]);

  ok(res, {
    since: since.toISOString(),
    serverTime: new Date().toISOString(),
    announcements: announcements.rows,
    reports: reports.rows,
    missingPersons: missing.rows,
    wantedPersons: wanted.rows,
    legal: legal.rows,
  });
};
