import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/db.js';
import { splitStatements } from './sql-split.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const file = process.argv[2] || 'schema.sql';
const sql = fs.readFileSync(path.join(__dirname, '..', 'src', 'db', file), 'utf8');

// Split into single statements so constructs such as `ALTER TYPE ... ADD VALUE`
// (which cannot run inside a transaction block) execute correctly.
const statements = splitStatements(sql);

try {
  let n = 0;
  for (const stmt of statements) {
    await pool.query(stmt);
    n++;
  }
  console.log(`[DB] Applied ${file} (${n} statements)`);
} catch (e) {
  console.error(`[DB] Failed to apply ${file}:`, e.message);
  process.exit(1);
} finally {
  await pool.end();
}
