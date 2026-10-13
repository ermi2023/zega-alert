import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { recordShare, shareStats, listPlatforms } from '../controllers/share.controller.js';

const router = Router();
router.use(authenticate);

router.get('/platforms', listPlatforms);
router.post('/', recordShare);
router.get('/stats', requireRole('regional_admin', 'system_admin'), shareStats);

export default router;
