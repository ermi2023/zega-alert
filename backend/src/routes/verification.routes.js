import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { submitVerification, getVerificationStatus, verifyByQr } from '../controllers/verification.controller.js';

const router = Router();
router.use(authenticate);
router.post('/submit', submitVerification);
router.post('/qr', verifyByQr);
router.get('/status', getVerificationStatus);

export default router;