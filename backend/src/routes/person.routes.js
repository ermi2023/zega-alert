import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createMissing, listMissing, getMissing, updateMissing, createSighting, listSightings,
  createWanted, listWanted, updateWanted, approveMissing, rejectMissing,
} from '../controllers/person.controller.js';

const router = Router();
router.use(authenticate);

router.get('/missing', listMissing);
router.post('/missing', createMissing);
router.get('/missing/:id', getMissing);
router.patch('/missing/:id', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), updateMissing);
router.patch('/missing/:id/approve', requireRole('regional_admin', 'system_admin'), approveMissing);
router.patch('/missing/:id/reject', requireRole('regional_admin', 'system_admin'), rejectMissing);

router.get('/wanted', listWanted);
router.post('/wanted', requireRole('police', 'regional_admin', 'system_admin'), createWanted);
router.patch('/wanted/:id', requireRole('police', 'regional_admin', 'system_admin'), updateWanted);

router.get('/sightings', listSightings);
router.post('/sightings', createSighting);

export default router;
