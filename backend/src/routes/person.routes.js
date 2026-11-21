import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import {
  createMissing, listMissing, getMissing, updateMissing, deleteMissing,
  createSighting, listSightings,
  createWanted, listWanted, updateWanted, deleteWanted,
  approveMissing, rejectMissing, publishMissing, unpublishMissing,
  approveWanted, rejectWanted, publishWanted, unpublishWanted,
  getMissingStats,
} from '../controllers/person.controller.js';

const router = Router();

// Public (guest) or authenticated staff read access.
router.get('/missing/stats', getMissingStats);
router.get('/missing', optionalAuth, listMissing);
router.get('/missing/:id', optionalAuth, getMissing);
router.get('/wanted', optionalAuth, listWanted);
router.get('/sightings', listSightings);

// Writes and staff-only views require an authenticated account.
router.post('/missing', authenticate, requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), createMissing);
router.patch('/missing/:id', authenticate, requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), updateMissing);
router.delete('/missing/:id', authenticate, requireRole('regional_admin', 'system_admin'), deleteMissing);
router.patch('/missing/:id/approve', authenticate, requireRole('regional_admin', 'system_admin'), approveMissing);
router.patch('/missing/:id/reject', authenticate, requireRole('regional_admin', 'system_admin'), rejectMissing);
router.patch('/missing/:id/publish', authenticate, requireRole('regional_admin', 'system_admin'), publishMissing);
router.patch('/missing/:id/unpublish', authenticate, requireRole('regional_admin', 'system_admin'), unpublishMissing);

router.post('/wanted', authenticate, requireRole('police', 'regional_admin', 'system_admin'), createWanted);
router.patch('/wanted/:id', authenticate, requireRole('police', 'regional_admin', 'system_admin'), updateWanted);
router.delete('/wanted/:id', authenticate, requireRole('regional_admin', 'system_admin'), deleteWanted);
router.patch('/wanted/:id/approve', authenticate, requireRole('regional_admin', 'system_admin'), approveWanted);
router.patch('/wanted/:id/reject', authenticate, requireRole('regional_admin', 'system_admin'), rejectWanted);
router.patch('/wanted/:id/publish', authenticate, requireRole('regional_admin', 'system_admin'), publishWanted);
router.patch('/wanted/:id/unpublish', authenticate, requireRole('regional_admin', 'system_admin'), unpublishWanted);

router.post('/sightings', authenticate, createSighting);

export default router;
