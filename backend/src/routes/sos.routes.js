import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createSos, listSos, getSos, updateSosStatus, assignSos,
} from '../controllers/sos.controller.js';
import {
  createSosLiveOffer, listActiveSosLiveOffers, answerSosLiveOffer,
  addSosLiveIceCandidate, endSosLiveStream,
} from '../controllers/sos-live.controller.js';

const router = Router();
router.use(authenticate);

router.post('/', createSos);
router.get('/', listSos);
router.get('/:id', getSos);
router.patch('/:id/status', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), updateSosStatus);
router.post('/:id/assign', requireRole('dispatcher', 'regional_admin', 'system_admin'), assignSos);
router.get('/live/active', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), listActiveSosLiveOffers);
router.post('/:id/live/offer', createSosLiveOffer);
router.post('/:id/live/answer', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), answerSosLiveOffer);
router.post('/:id/live/ice', addSosLiveIceCandidate);
router.post('/:id/live/end', endSosLiveStream);

export default router;
