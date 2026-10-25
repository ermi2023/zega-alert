import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  listNotifications, markRead, markAllRead, sendNotification,
} from '../controllers/notification.controller.js';

const router = Router();

router.use(authenticate);

router.get('/', listNotifications);
router.patch('/read-all', markAllRead);
router.post('/read-all', markAllRead);
router.patch('/:id/read', markRead);
router.post('/:id/read', markRead);
router.post('/', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), sendNotification);

export default router;
