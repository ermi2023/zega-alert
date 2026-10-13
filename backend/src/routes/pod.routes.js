import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  requestDirectCall, listDirectCalls, updateDirectCall,
  submitSignLanguage, listSignLanguage, listStations, createStation,
} from '../controllers/pod.controller.js';

const router = Router();
router.use(authenticate);

// People of Determination - citizen actions
router.post('/direct-call', requestDirectCall);
router.get('/direct-call', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), listDirectCalls);
router.patch('/direct-call/:id', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), updateDirectCall);

router.post('/sign-language', submitSignLanguage);
router.get('/sign-language', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), listSignLanguage);

// Police stations (nearest-station lookup)
router.get('/stations', listStations);
router.post('/stations', requireRole('system_admin', 'regional_admin'), createStation);

export default router;
