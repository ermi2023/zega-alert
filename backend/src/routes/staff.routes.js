import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { listStaff } from '../controllers/staff.controller.js';

const router = Router();
router.use(authenticate);
router.use(requireRole('dispatcher', 'police', 'regional_admin', 'system_admin'));

router.get('/', listStaff);

export default router;
