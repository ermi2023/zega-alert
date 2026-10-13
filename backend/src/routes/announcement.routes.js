import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createAnnouncement, listAnnouncements, getAnnouncement, updateAnnouncement, deleteAnnouncement,
  retranslateAnnouncement,
} from '../controllers/announcement.controller.js';

const router = Router();
router.use(authenticate);

router.get('/', listAnnouncements);
router.get('/:id', getAnnouncement);
router.post('/', requireRole('police', 'regional_admin', 'system_admin'), createAnnouncement);
router.post('/:id/retranslate', requireRole('regional_admin', 'system_admin'), retranslateAnnouncement);
router.patch('/:id', requireRole('regional_admin', 'system_admin'), updateAnnouncement);
router.delete('/:id', requireRole('system_admin'), deleteAnnouncement);

export default router;
