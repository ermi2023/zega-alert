import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createMissing, listMissing, getMissing, updateMissing, createSighting, listSightings,
  createWanted, listWanted, updateWanted, approveMissing, rejectMissing, getMissingStats,
} from '../controllers/person.controller.js';

const router = Router();

// Public (guest) read access.
router.get('/missing/stats', getMissingStats);
router.get('/missing', listMissing);
router.get('/missing/:id', getMissing);
router.get('/wanted', listWanted);
router.get('/sightings', listSightings);

// Writes and staff-only views require an authenticated account.
router.post('/missing', authenticate, createMissing);
router.patch('/missing/:id', authenticate, requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), updateMissing);
router.patch('/missing/:id/approve', authenticate, requireRole('regional_admin', 'system_admin'), approveMissing);
router.patch('/missing/:id/reject', authenticate, requireRole('regional_admin', 'system_admin'), rejectMissing);

router.post('/wanted', authenticate, requireRole('police', 'regional_admin', 'system_admin'), createWanted);
router.patch('/wanted/:id', authenticate, requireRole('police', 'regional_admin', 'system_admin'), updateWanted);

router.post('/sightings', authenticate, createSighting);

export default router;
