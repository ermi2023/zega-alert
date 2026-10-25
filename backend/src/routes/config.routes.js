import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  listConfig, getConfig, setConfig, bulkSetConfig,
} from '../controllers/config.controller.js';

const router = Router();

router.use(authenticate);

router.get('/', listConfig);
router.get('/:key', getConfig);
router.put('/:key', requireRole('system_admin'), setConfig);
router.post('/bulk', requireRole('system_admin'), bulkSetConfig);

export default router;
