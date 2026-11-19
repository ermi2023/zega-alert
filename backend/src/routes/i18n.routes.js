import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { getUiBundle, listLanguages } from '../controllers/i18n.controller.js';

const router = Router();

// UI localization bundle for a language. Any logged-in user can fetch —
// the endpoint is read-only and returns translated UI strings only.
router.get('/languages', authenticate, listLanguages);
router.get('/bundle/:lang', authenticate, getUiBundle);

export default router;
