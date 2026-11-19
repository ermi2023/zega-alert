import 'dotenv/config';
import pg from 'pg';
import { env } from '../src/config/env.js';

const pool = new pg.Pool({
  connectionString: env.databaseUrl,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 15000,
});

const out = await pool.query(
  `SELECT id, phone, full_name, role, is_active FROM users ORDER BY id LIMIT 50`
);
console.log(`users count: ${out.rows.length}`);
for (const u of out.rows) {
  console.log(`  #${u.id} phone=${u.phone} role=${u.role} active=${u.is_active} name=${u.full_name}`);
}
await pool.end();
