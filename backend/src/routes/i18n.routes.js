import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { getUiBundle, listLanguages, translateStrings } from '../controllers/i18n.controller.js';

const router = Router();

// UI localization bundle for a language. Any logged-in user can fetch —
// the endpoint is read-only and returns translated UI strings only.
router.get('/languages', authenticate, listLanguages);
router.get('/bundle/:lang', authenticate, getUiBundle);

// One-shot string translation (dev tool for generating static bundles like
// app_so.arb). Restricted to system_admin so it can't be abused as an open
// translate proxy at runtime.
router.post('/translate-strings', authenticate, requireRole('system_admin'), translateStrings);

export default router;
