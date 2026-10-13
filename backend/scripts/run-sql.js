import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const file = process.argv[2] || 'schema.sql';
const sql = fs.readFileSync(path.join(__dirname, '..', 'src', 'db', file), 'utf8');

try {
  await pool.query(sql);
  console.log(`[DB] Applied ${file}`);
} catch (e) {
  console.error(`[DB] Failed to apply ${file}:`, e.message);
  process.exit(1);
} finally {
  await pool.end();
}
