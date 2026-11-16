import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  register, requestOtp, verifyOtpEndpoint, login, loginWithOtp,
  refresh, logout, me, updateMe, changePassword, searchStaff, verifyAdminOtp, resetPassword,
} from '../controllers/auth.controller.js';

const router = Router();

router.post('/register', register);
router.post('/request-otp', requestOtp);
router.post('/verify-otp', verifyOtpEndpoint);
router.post('/reset-password', resetPassword);
router.post('/login', login);
router.post('/verify-admin-otp', verifyAdminOtp);
router.post('/login-otp', loginWithOtp);
router.post('/refresh', refresh);
router.post('/logout', logout);

router.use(authenticate);
router.get('/me', me);
router.put('/me', updateMe);
router.put('/change-password', changePassword);
router.get('/staff', searchStaff);

export default router;
