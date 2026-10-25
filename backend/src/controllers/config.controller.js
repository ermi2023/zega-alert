import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';

/**
 * GET /api/config
 * Returns all system_config settings.
 */
export async function listConfig(req, res) {
  try {
    const { rows } = await query(
      'SELECT id, setting_name, setting_value, last_modified FROM system_config ORDER BY setting_name'
    );
    const config = {};
    for (const row of rows) {
      config[row.setting_name] = {
        value: row.setting_value,
        last_modified: row.last_modified,
      };
    }
    ok(res, { config, settings: rows });
  } catch (err) {
    console.error('[config] listConfig error:', err);
    fail(res, 'Failed to load system config', 500);
  }
}

/**
 * GET /api/config/:name
 * Returns a single config setting.
 */
export async function getConfig(req, res) {
  try {
    const { key, name } = req.params;
    const settingName = key || name;
    const { rows } = await query(
      'SELECT id, setting_name, setting_value, last_modified FROM system_config WHERE setting_name = $1',
      [settingName]
    );
    if (!rows.length) return fail(res, 'Config setting not found', 404);
    ok(res, rows[0]);
  } catch (err) {
    console.error('[config] getConfig error:', err);
    fail(res, 'Failed to get config setting', 500);
  }
}

/**
 * PUT /api/config/:name
 * Upserts a config setting. System admin only.
 */
export async function setConfig(req, res) {
  try {
    const { key, name } = req.params;
    const settingName = key || name;
    const { setting_value, value } = req.body;
    const val = setting_value !== undefined ? setting_value : value;
    if (val === undefined) return fail(res, 'value or setting_value is required', 400);

    const valStr = typeof val === 'object' ? JSON.stringify(val) : String(val);

    const { rows } = await query(
      `INSERT INTO system_config (setting_name, setting_value, last_modified)
       VALUES ($1, $2, NOW())
       ON CONFLICT (setting_name) DO UPDATE
       SET setting_value = EXCLUDED.setting_value,
           last_modified = NOW()
       RETURNING id, setting_name, setting_value, last_modified`,
      [settingName, valStr]
    );
    ok(res, rows[0], 'Config updated');
  } catch (err) {
    console.error('[config] setConfig error:', err);
    fail(res, 'Failed to update config', 500);
  }
}

/**
 * POST /api/config/bulk
 * Bulk-upserts multiple config keys. System admin only.
 * Body: { config: { setting_name: value, ... } }
 */
export async function bulkSetConfig(req, res) {
  try {
    const { config } = req.body;
    if (!config || typeof config !== 'object') {
      return fail(res, 'config object is required', 400);
    }

    const entries = Object.entries(config);
    if (!entries.length) return fail(res, 'config object must not be empty', 400);

    const results = [];
    for (const [settingName, val] of entries) {
      const valStr = typeof val === 'object' ? JSON.stringify(val) : String(val);
      const { rows } = await query(
        `INSERT INTO system_config (setting_name, setting_value, last_modified)
         VALUES ($1, $2, NOW())
         ON CONFLICT (setting_name) DO UPDATE
         SET setting_value = EXCLUDED.setting_value,
             last_modified = NOW()
         RETURNING id, setting_name, setting_value, last_modified`,
        [settingName, valStr]
      );
      results.push(rows[0]);
    }
    ok(res, { updated: results }, 'Bulk config updated');
  } catch (err) {
    console.error('[config] bulkSetConfig error:', err);
    fail(res, 'Failed to bulk update config', 500);
  }
}
