import { validationResult } from 'express-validator';
import { fail } from '../utils/response.js';

export const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return fail(res, 'Validation failed', 422, errors.array().map((e) => e.msg));
  }
  next();
};

export const notFound = (req, res) =>
  fail(res, `Route not found: ${req.method} ${req.originalUrl}`, 404);

export const errorHandler = (err, req, res, next) => {
  console.error(err);
  const status = err.status || 500;
  const message = status >= 500 ? 'Internal server error' : err.message;
  res.status(status).json({ success: false, message, errors: err.errors });
};
