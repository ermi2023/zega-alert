import { verifyToken } from '../utils/jwt.js';

const buckets = new Map();

const CLEANUP_INTERVAL = 60000;
let lastCleanup = Date.now();

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

export const rateLimit = ({ windowMs = 60000, max = 100, key = defaultKey } = {}) =>
  (req, res, next) => {
    cleanup();
    const k = key(req);
    const now = Date.now();
    const bucket = buckets.get(k) || { count: 0, resetAt: now + windowMs };
    if (bucket.resetAt <= now) {
      bucket.count = 0;
      bucket.resetAt = now + windowMs;
    }
    bucket.count += 1;
    buckets.set(k, bucket);
    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, max - bucket.count));
    if (bucket.count > max) {
      res.setHeader('Retry-After', Math.ceil((bucket.resetAt - now) / 1000));
      return res.status(429).json({ success: false, message: 'Too many requests, slow down' });
    }
    next();
  };
