import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

/**
 * GET /api/admin/analytics
 * Returns dashboard analytics: weekly trend, response time, resolution rate,
 * SOS by region, crime by category, reports by severity.
 */
export const getAnalytics = async (req, res) => {
  try {
    // 1. Weekly trend — reports per day for the last 14 days
    const weeklyTrend = await query(
      `SELECT DATE(reported_at) AS date, COUNT(*)::int AS count
       FROM reports
       WHERE reported_at >= NOW() - INTERVAL '14 days'
       GROUP BY DATE(reported_at)
       ORDER BY date`,
    );

    // 2. Response time — avg seconds from SOS created_at to first dispatch assignment
    const responseTime = await query(
      `SELECT COALESCE(
         AVG(EXTRACT(EPOCH FROM (da.created_at - s.created_at))), 0
       )::float AS avg_seconds
       FROM sos_alerts s
       INNER JOIN LATERAL (
         SELECT created_at FROM dispatch_assignments
         WHERE sos_id = s.id
         ORDER BY created_at ASC
         LIMIT 1
       ) da ON true`,
    );

    // 3. Resolution rate — percentage of reports with status 'resolved'
    const resolutionRate = await query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'resolved')::int AS resolved,
         COUNT(*)::int AS total
       FROM reports`,
    );
    const { resolved, total } = resolutionRate.rows[0];
    const resolutionPct = total > 0 ? parseFloat(((resolved / total) * 100).toFixed(2)) : 0;

    // 4. SOS by region
    const sosByRegion = await query(
      `SELECT region, COUNT(*)::int AS count
       FROM sos_alerts
       WHERE region IS NOT NULL
       GROUP BY region
       ORDER BY count DESC`,
    );

    // 5. Crime by category
    const crimeByCategory = await query(
      `SELECT category, COUNT(*)::int AS count
       FROM reports
       WHERE category IS NOT NULL
       GROUP BY category
       ORDER BY count DESC`,
    );

    // 6. Reports by severity
    const reportsBySeverity = await query(
      `SELECT severity, COUNT(*)::int AS count
       FROM reports
       WHERE severity IS NOT NULL
       GROUP BY severity
       ORDER BY count DESC`,
    );

    ok(res, {
      weekly_trend: weeklyTrend.rows,
      response_time: responseTime.rows[0]?.avg_seconds ?? 0,
      resolution_rate: resolutionPct,
      sos_by_region: sosByRegion.rows,
      crime_by_category: crimeByCategory.rows,
      reports_by_severity: reportsBySeverity.rows,
    });
  } catch (err) {
    console.error('[Analytics] getAnalytics error:', err);
    fail(res, 'Failed to fetch analytics', 500);
  }
};

/**
 * GET /api/admin/heatmap
 * Returns lat/lng/weight points from reports + sos_alerts for the last 90 days.
 */
export const getHeatmap = async (req, res) => {
  try {
    const result = await query(
      `SELECT latitude, longitude, 1 AS weight FROM reports
       WHERE latitude IS NOT NULL AND longitude IS NOT NULL
         AND reported_at >= NOW() - INTERVAL '90 days'
       UNION ALL
       SELECT latitude, longitude, 2 AS weight FROM sos_alerts
       WHERE latitude IS NOT NULL AND longitude IS NOT NULL
         AND created_at >= NOW() - INTERVAL '90 days'`,
    );
    ok(res, result.rows);
  } catch (err) {
    console.error('[Analytics] getHeatmap error:', err);
    fail(res, 'Failed to fetch heatmap data', 500);
  }
};
