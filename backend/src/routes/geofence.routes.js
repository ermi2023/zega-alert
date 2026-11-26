import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  listGeofences, createGeofence, updateGeofence, deleteGeofence,
} from '../controllers/geofence.controller.js';

const router = Router();
router.use(authenticate);

router.get('/', listGeofences);
router.post('/', requireRole('system_admin', 'regional_admin', 'dispatcher'), createGeofence);
router.patch('/:id', requireRole('system_admin', 'regional_admin', 'dispatcher'), updateGeofence);
router.delete('/:id', requireRole('system_admin', 'regional_admin'), deleteGeofence);

export default router;
