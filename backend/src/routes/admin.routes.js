import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { stats, listUsers, createUser, updateUser, deleteUser, listAudit, listDispatches } from '../controllers/admin.controller.js';

const router = Router();
router.use(authenticate, requireRole('regional_admin', 'system_admin'));

router.get('/stats', stats);
router.get('/users', listUsers);
router.post('/users', requireRole('system_admin'), createUser);
router.patch('/users/:id', requireRole('system_admin'), updateUser);
router.delete('/users/:id', requireRole('system_admin'), deleteUser);
router.get('/audit', listAudit);
router.get('/dispatches', listDispatches);

export default router;
