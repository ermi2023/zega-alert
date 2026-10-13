import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { getPolicy, updatePolicy } from '../controllers/policy.controller.js';

const router = Router();
router.use(authenticate);
router.get('/', getPolicy);
router.put('/', updatePolicy);

export default router;
