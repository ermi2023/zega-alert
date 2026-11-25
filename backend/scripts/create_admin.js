import bcrypt from 'bcryptjs';
import { env } from '../src/config/env.js';
import { query } from '../src/config/db.js';

const args = process.argv.slice(2);
const cliValue = (flag) => {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
};

const phone = cliValue('--phone') || process.env.ADMIN_PHONE;
const email = cliValue('--email') || process.env.ADMIN_EMAIL;
const plainPassword = cliValue('--password') || process.env.ADMIN_PASSWORD;
const fullName = cliValue('--name') || process.env.ADMIN_NAME || 'System Admin';

async function setupAdmin() {
  if (!phone || !email || !plainPassword) {
    throw new Error('ADMIN_PHONE, ADMIN_EMAIL and ADMIN_PASSWORD (or --phone, --email, --password) are required');
  }
  if (env.nodeEnv === 'production' && process.env.ALLOW_PRODUCTION_ADMIN_SETUP !== 'true') {
    throw new Error('Refusing to create/administer an admin in production without ALLOW_PRODUCTION_ADMIN_SETUP=true');
  }

  const hash = await bcrypt.hash(plainPassword, 12);

  const existing = await query(
    'SELECT id, phone, email FROM users WHERE phone = $1 OR email = $2',
    [phone, email],
  );
  if (existing.rows.length > 1) {
    throw new Error('Phone and email match different users; refusing to modify accounts');
  }

  const row = existing.rows[0];
  let result;
  if (row) {
    if (row.phone !== phone || row.email !== email) {
      throw new Error('Phone/email conflict with an existing user; refusing to overwrite');
    }
    const updated = await query(
      `UPDATE users SET password_hash = $1, role = 'system_admin', is_active = true, is_verified = true, updated_at = now()
       WHERE id = $2 RETURNING id, full_name, phone, email, role`,
      [hash, row.id],
    );
    result = updated.rows[0];
  } else {
    const inserted = await query(
      `INSERT INTO users (full_name, phone, email, password_hash, role, region, sub_city, woreda, is_active, is_verified)
       VALUES ($1, $2, $3, $4, 'system_admin', 'Addis Ababa', 'Bole', '03', true, true)
       ON CONFLICT (phone) DO UPDATE
       SET password_hash = EXCLUDED.password_hash, role = 'system_admin', is_active = true, is_verified = true, updated_at = now()
       RETURNING id, full_name, phone, email, role`,
      [fullName, phone, email, hash],
    );
    result = inserted.rows[0];
  }

  console.log('System admin ready:', result);
}

setupAdmin().then(() => process.exit(0)).catch((err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
