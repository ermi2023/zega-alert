import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { reportPosition, getOfficerPositions, reportSosLocation } from '../controllers/position.controller.js';

const router = Router();
router.use(authenticate);
router.post('/report', reportPosition);
router.post('/sos', reportSosLocation);
router.get('/officers', getOfficerPositions);

export default router;
