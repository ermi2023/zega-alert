import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  requestCallback, respondToCallback, listCallbacks, listCallbacksForOfficer,
} from '../controllers/callback.controller.js';

const router = Router();
router.use(authenticate);

router.post('/', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), requestCallback);
router.get('/mine', listCallbacks);
router.get('/officer', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), listCallbacksForOfficer);
router.patch('/:id', respondToCallback);

export default router;
