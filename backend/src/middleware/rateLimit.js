import { verifyToken } from '../utils/jwt.js';
import { getSecurityPolicy } from '../services/security-policy.service.js';

const buckets = new Map();

const CLEANUP_INTERVAL = 60000;
const POLICY_TTL = 60000;
let lastCleanup = Date.now();
let cachedPolicyLimit = 100;
let cachedPolicyAt = 0;

const policyRateLimit = async () => {
  const now = Date.now();
  if (now - cachedPolicyAt < POLICY_TTL) return cachedPolicyLimit;
  try {
    const policy = await getSecurityPolicy();
    cachedPolicyLimit = Math.max(1, Number(policy.rate_limit_per_minute) || 100);
  } catch {
    cachedPolicyLimit = 100;
  }
  cachedPolicyAt = now;
  return cachedPolicyLimit;
};

const cleanup = () => {
  const now = Date.now();
  if (now - lastCleanup < CLEANUP_INTERVAL) return;
  lastCleanup = now;
  for (const [k, bucket] of buckets) {
    if (bucket.resetAt <= now) buckets.delete(k);
  }
};

// NFR-07: 100 requests per minute per user. Falls back to IP for unauthenticated calls.
const defaultKey = (req) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (token) {
    try {
      return `user:${verifyToken(token).sub}`;
    } catch {
      // fall through to IP keying
    }
  }
  return `ip:${req.ip}`;
};

export const rateLimit = ({ windowMs = 60000, max = null, key = defaultKey } = {}) =>
  async (req, res, next) => {
    cleanup();
    const limit = max ?? await policyRateLimit();
    const k = key(req);
    const now = Date.now();
    const bucket = buckets.get(k) || { count: 0, resetAt: now + windowMs };
    if (bucket.resetAt <= now) {
      bucket.count = 0;
      bucket.resetAt = now + windowMs;
    }
    bucket.count += 1;
    buckets.set(k, bucket);
    res.setHeader('X-RateLimit-Limit', limit);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, limit - bucket.count));
    if (bucket.count > limit) {
      res.setHeader('Retry-After', Math.ceil((bucket.resetAt - now) / 1000));
      return res.status(429).json({ success: false, message: 'Too many requests, slow down' });
    }
    next();
  };
