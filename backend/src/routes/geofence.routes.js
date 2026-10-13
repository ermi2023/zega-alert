import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  listGeofences, createGeofence, updateGeofence, deleteGeofence,
} from '../controllers/geofence.controller.js';

const router = Router();
router.use(authenticate);

router.get('/', listGeofences);
router.post('/', createGeofence);
router.patch('/:id', updateGeofence);
router.delete('/:id', deleteGeofence);

export default router;
