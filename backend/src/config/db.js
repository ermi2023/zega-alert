import pg from 'pg';
import { env } from './env.js';

const { Pool } = pg;

// Hosted Postgres providers (Supabase, Neon, Render) require TLS. Local dev
// does not, so only enable SSL for non-local hosts.
const isLocal = /(?:localhost|127\.0\.0\.1)/.test(env.databaseUrl);
const useSsl = !isLocal || env.nodeEnv === 'production';

export const pool = new Pool({
  connectionString: env.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30000,
  ssl: useSsl ? { rejectUnauthorized: false } : false,
});

if (env.supabaseEnabled) {
  console.log('[DB] Supabase configured — using hosted Postgres');
}

export const query = (text, params) => pool.query(text, params);

export default pool;
