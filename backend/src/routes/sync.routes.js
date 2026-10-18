import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { sync } from '../controllers/sync.controller.js';

const router = Router();
router.use(authenticate);
router.get('/', sync);

export default router;
