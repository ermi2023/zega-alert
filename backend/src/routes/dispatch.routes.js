import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  assignUnits, removeUnit, listAssignedUnits, updateUnitStatus,
} from '../controllers/dispatch.controller.js';

const router = Router();
router.use(authenticate);
router.use(requireRole('dispatcher', 'regional_admin', 'system_admin'));

router.post('/:sosId/assign', assignUnits);
router.delete('/:sosId/:assignmentId', removeUnit);
router.get('/:sosId/units', listAssignedUnits);
router.patch('/:sosId/:assignmentId/status', updateUnitStatus);

export default router;
