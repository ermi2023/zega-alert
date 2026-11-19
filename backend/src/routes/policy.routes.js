import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { getPolicy, updatePolicy } from '../controllers/policy.controller.js';

const router = Router();
router.use(authenticate);

router.get('/', getPolicy);
// Only System Admin may change platform-wide security policy (spec §4.3.7).
router.put('/', requireRole('system_admin'), updatePolicy);

export default router;
