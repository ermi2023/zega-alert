import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createAnnouncement, listAnnouncements, getAnnouncement, updateAnnouncement, deleteAnnouncement,
  retranslateAnnouncement,
} from '../controllers/announcement.controller.js';

const router = Router();

// Public (guest) read access so people can browse without an account.
router.get('/', listAnnouncements);
router.get('/:id', getAnnouncement);

// Writes require an authenticated account.
router.post('/', authenticate, requireRole('police', 'regional_admin', 'system_admin'), createAnnouncement);
router.post('/:id/retranslate', authenticate, requireRole('regional_admin', 'system_admin'), retranslateAnnouncement);
router.patch('/:id', authenticate, requireRole('regional_admin', 'system_admin'), updateAnnouncement);
router.delete('/:id', authenticate, requireRole('system_admin'), deleteAnnouncement);

export default router;
