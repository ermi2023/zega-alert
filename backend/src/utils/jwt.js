import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export const signTokens = (user) => {
  // `ver` ties every token to the user's current token_version. Logout
  // increments token_version, which invalidates all outstanding tokens.
  const payload = { sub: user.id, role: user.role, ver: user.token_version ?? 0 };
  return {
    accessToken: jwt.sign(payload, env.jwtSecret, { expiresIn: env.jwtExpiresIn }),
    refreshToken: jwt.sign({ ...payload, type: 'refresh' }, env.jwtSecret, { expiresIn: env.jwtRefreshExpiresIn }),
  };
};

export const verifyToken = (token) => jwt.verify(token, env.jwtSecret);
