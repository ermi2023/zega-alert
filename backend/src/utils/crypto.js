import crypto from 'crypto';
import { env } from '../config/env.js';

// AES-256-GCM encryption for selected PII fields stored at rest.
// Ciphertext is self-describing ("enc:v1:iv:tag:data") so decryption is
// transparent and old plaintext rows keep working unchanged.

const PREFIX = 'enc:v1:';
const ALGO = 'aes-256-gcm';
let _key = null;

function getKey() {
  if (_key) return _key;
  const raw = env.encryptionKey;
  if (raw) {
    if (/^[0-9a-fA-F]{64}$/.test(raw)) {
      _key = Buffer.from(raw, 'hex');
    } else {
      const b64 = Buffer.from(raw, 'base64');
      _key = b64.length === 32 ? b64 : crypto.createHash('sha256').update(raw).digest();
    }
  } else {
    // Deterministic dev key so data stays readable across restarts.
    _key = crypto.createHash('sha256').update(`zega-at-rest:${env.jwtSecret}`).digest();
  }
  return _key;
}

export function isEncrypted(value) {
  return typeof value === 'string' && value.startsWith(PREFIX);
}

export function encrypt(plain) {
  if (plain == null || plain === '') return plain;
  if (isEncrypted(plain)) return plain;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGO, getKey(), iv);
  const data = Buffer.concat([cipher.update(String(plain), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return PREFIX + [iv.toString('base64'), tag.toString('base64'), data.toString('base64')].join(':');
}

export function decrypt(value) {
  if (!isEncrypted(value)) return value;
  try {
    const [ivB64, tagB64, dataB64] = value.slice(PREFIX.length).split(':');
    const decipher = crypto.createDecipheriv(ALGO, getKey(), Buffer.from(ivB64, 'base64'));
    decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
    const out = Buffer.concat([decipher.update(Buffer.from(dataB64, 'base64')), decipher.final()]);
    return out.toString('utf8');
  } catch {
    return value;
  }
}
