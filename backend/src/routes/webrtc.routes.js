import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { createOffer, createAnswer, addIceCandidate, endCall } from '../controllers/webrtc.controller.js';

const router = Router();
router.use(authenticate);
router.post('/offer', createOffer);
router.post('/answer', createAnswer);
router.post('/ice-candidate', addIceCandidate);
router.post('/end', endCall);

export default router;
