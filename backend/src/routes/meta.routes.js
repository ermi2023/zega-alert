import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { country } from '../controllers/meta.controller.js';

const router = Router();
router.use(authenticate);

router.get('/country', country);

export default router;
