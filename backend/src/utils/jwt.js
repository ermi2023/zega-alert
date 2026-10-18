import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import { env } from '../config/env.js';

export const signTokens = (user) => {
  // `ver` ties every token to the user's current token_version. Logout
  // increments token_version, which invalidates all outstanding tokens.
  const payload = { sub: user.id, role: user.role, ver: user.token_version ?? 0 };
  const jti = crypto.randomBytes(16).toString('hex');
  return {
    accessToken: jwt.sign(payload, env.jwtSecret, { expiresIn: env.jwtExpiresIn }),
    refreshToken: jwt.sign({ ...payload, type: 'refresh', jti }, env.jwtSecret, { expiresIn: env.jwtRefreshExpiresIn }),
    refreshTokenJti: jti,
  };
};

export const verifyToken = (token) => jwt.verify(token, env.jwtSecret);
