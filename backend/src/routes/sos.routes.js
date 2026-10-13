import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createSos, listSos, getSos, updateSosStatus, assignSos,
} from '../controllers/sos.controller.js';

const router = Router();
router.use(authenticate);

router.post('/', createSos);
router.get('/', listSos);
router.get('/:id', getSos);
router.patch('/:id/status', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), updateSosStatus);
router.post('/:id/assign', requireRole('dispatcher', 'regional_admin', 'system_admin'), assignSos);

export default router;
