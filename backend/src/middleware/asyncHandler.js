import { Router } from 'express';

// Express 4 does not forward rejected promises from async route handlers to the
// error middleware, which leaves the client request hanging. This patches the
// Router prototype so any async handler that throws is routed to `next(err)`.
//
// IMPORTANT: this module must be imported before any route module so the patch
// is in place when routers are created.

const wrap = (fn) => function asyncWrapped(req, res, next) {
  Promise.resolve(fn(req, res, next)).catch(next);
};

const shouldWrap = (arg) => typeof arg === 'function' && arg.length < 4;

for (const method of ['get', 'post', 'put', 'patch', 'delete', 'all', 'use']) {
  const original = Router.prototype[method];
  if (!original || original.__asyncWrapped) continue;
  const patched = function (...args) {
    return original.apply(this, args.map((a) => (shouldWrap(a) ? wrap(a) : a)));
  };
  patched.__asyncWrapped = true;
  Router.prototype[method] = patched;
}
