import pg from 'pg';
import { env } from './env.js';

const { Pool } = pg;

// Decide whether the Postgres connection should use TLS.
//  - Hosted providers reachable over the public internet (Neon, Supabase,
//    Render *external* URLs) require TLS.
//  - Render's *internal* database hostname has no dots (private network) and
//    does NOT speak TLS, so forcing SSL would break the connection.
//  - localhost / 127.0.0.1 never use TLS.
// Override explicitly with DB_SSL=true|false.
function needsSsl(url) {
  if (env.dbSsl === 'true') return true;
  if (env.dbSsl === 'false') return false;
  try {
    const host = new URL(url).hostname;
    if (host === 'localhost' || host === '127.0.0.1' || host === '::1') return false;
    return host.includes('.');
  } catch {
    return false;
  }
}

export const pool = new Pool({
  connectionString: env.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30000,
  ssl: needsSsl(env.databaseUrl) ? { rejectUnauthorized: false } : false,
});

if (env.supabaseEnabled) {
  console.log('[DB] Supabase configured — using hosted Postgres');
}

export const query = (text, params) => pool.query(text, params);

export default pool;
