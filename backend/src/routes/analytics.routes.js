import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { getAnalytics, getHeatmap } from '../controllers/analytics.controller.js';

const router = Router();

router.use(authenticate);
router.use(requireRole('system_admin', 'regional_admin'));

router.get('/analytics', getAnalytics);
router.get('/heatmap', getHeatmap);

export default router;
