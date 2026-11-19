import { Router } from 'express';
import { optionalAuth } from '../middleware/optionalAuth.js';
import { translate, listLanguages } from '../controllers/translate.controller.js';

const router = Router();

// Soft auth: logged-in users get higher rate limits implicitly via req.user;
// guests (no token) are still allowed because news/persons feeds are public.
router.use(optionalAuth);

// GET /api/translate/languages — list supported languages + short codes.
router.get('/languages', listLanguages);

// POST /api/translate — translate text or array of texts.
router.post('/', translate);

export default router;
