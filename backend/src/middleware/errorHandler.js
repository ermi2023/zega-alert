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
  let status = err.status || err.statusCode || 500;
  let message = err.message;

  // Body-parser throws a SyntaxError for invalid JSON — return a clean 400.
  if (err.type === 'entity.parse.failed' || (err instanceof SyntaxError && status === 400)) {
    status = 400;
    message = 'Malformed JSON body. Ensure the request body is valid JSON.';
  }

  if (status >= 500) {
    console.error('[ERROR]', err);
    message = 'Internal server error';
  }

  res.status(status).json({
    success: false,
    message,
    ...(err.errors ? { errors: err.errors } : {}),
  });
};
