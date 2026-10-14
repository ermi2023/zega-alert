import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/db.js';
import { splitStatements } from './sql-split.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbDir = path.join(__dirname, '..', 'src', 'db');

async function applyFile(file, { tolerant }) {
  const full = path.join(dbDir, file);
  if (!fs.existsSync(full)) {
    console.log(`[DB] ${file} not found — skipping`);
    return;
  }
  const statements = splitStatements(fs.readFileSync(full, 'utf8'));
  let ok = 0;
  let failed = 0;
  for (const stmt of statements) {
    try {
      await pool.query(stmt);
      ok++;
    } catch (e) {
      failed++;
      if (!tolerant) throw new Error(`${file}: ${e.message}`);
      console.warn(`[DB] ${file} (ignored): ${e.message}`);
    }
  }
  console.log(`[DB] Applied ${file} (${ok} ok${failed ? `, ${failed} ignored` : ''})`);
}

try {
  await applyFile('schema.sql', { tolerant: false });
  await applyFile('migration_defence.sql', { tolerant: true });
  await applyFile('migration_gaps.sql', { tolerant: false });
  await applyFile('seed.sql', { tolerant: true });
  console.log('[DB] Migrations complete');
} catch (e) {
  console.error('[DB] Migration failed:', e.message);
  process.exit(1);
} finally {
  await pool.end();
}
