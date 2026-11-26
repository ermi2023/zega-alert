import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { submitVerification, getVerificationStatus, verifyByQr, verifyByFan } from '../controllers/verification.controller.js';

const router = Router();
router.use(authenticate);
router.post('/submit', submitVerification);
router.post('/fan', verifyByFan);
router.post('/qr', verifyByQr);
router.get('/status', getVerificationStatus);

export default router;