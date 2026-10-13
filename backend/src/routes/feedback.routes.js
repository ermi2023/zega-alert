import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { submitFeedback, myFeedback, listFeedback, avgRating } from '../controllers/feedback.controller.js';

const router = Router();
router.use(authenticate);

router.post('/:id/feedback', submitFeedback);
router.get('/my', myFeedback);
router.get('/all', requireRole('regional_admin', 'system_admin', 'police', 'dispatcher'), listFeedback);
router.get('/summary', requireRole('regional_admin', 'system_admin'), avgRating);

export default router;
