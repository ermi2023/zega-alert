import 'dotenv/config';
import pg from 'pg';
import { env } from '../src/config/env.js';

const url = new URL(env.databaseUrl);
console.log('Supabase DB host:', url.host);
console.log('Database:', url.pathname);
console.log('SSL:', env.dbSsl);

const pool = new pg.Pool({
  connectionString: env.databaseUrl,
  ssl: env.dbSsl === 'true' || env.dbSsl === ''
    ? { rejectUnauthorized: false }
    : env.dbSsl === 'false' ? false : undefined,
  connectionTimeoutMillis: 15000,
});

try {
  const res = await pool.query('SELECT version() AS v, current_database() AS db, current_user AS u');
  console.log('✅ Connected:', res.rows[0].v);
  console.log('   database:', res.rows[0].db);
  console.log('   user:', res.rows[0].u);
  const tables = await pool.query(
    `SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename`
  );
  console.log(`   existing tables in public: ${tables.rows.length}`);
  if (tables.rows.length > 0) {
    console.log('   ', tables.rows.map(r => r.tablename).slice(0, 10).join(', '),
      tables.rows.length > 10 ? `... (+${tables.rows.length - 10} more)` : '');
  }
  await pool.end();
} catch (e) {
  console.error('❌ Connection failed:', e.message);
  await pool.end().catch(() => {});
  process.exit(1);
}
