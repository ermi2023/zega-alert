import bcrypt from 'bcryptjs';
import { query } from '../src/config/db.js';

async function setupAdmin() {
  const phone = '0911000006';
  const email = 'admin@zega.et';
  const plainPassword = 'password123';
  const hash = await bcrypt.hash(plainPassword, 10);

  console.log(`Setting up system_admin with phone: ${phone}, email: ${email}...`);

  await query(`
    DELETE FROM users WHERE phone IN ('0911000006', '0978193376') OR email = $1
  `, [email]);

  const { rows } = await query(`
    INSERT INTO users (
      full_name, phone, email, password_hash, role,
      region, sub_city, woreda, is_active, is_verified
    ) VALUES (
      'System Admin', $1, $2, $3, 'system_admin',
      'Addis Ababa', 'Bole', '03', true, true
    ) RETURNING id, full_name, phone, email, role
  `, [phone, email, hash]);

  console.log('Successfully created/reset System Admin:', rows[0]);
  process.exit(0);
}

setupAdmin().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
