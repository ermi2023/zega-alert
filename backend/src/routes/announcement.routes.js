import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createAnnouncement, listAnnouncements, getAnnouncement, updateAnnouncement, deleteAnnouncement,
  retranslateAnnouncement, getPodcastFeed, getAnnouncementAudio,
} from '../controllers/announcement.controller.js';

const router = Router();

// Podcast RSS 2.0 XML feed & audio bulletins (doc 2.2 #2)
router.get('/podcast.xml', getPodcastFeed);
router.get('/feed/podcast.xml', getPodcastFeed);
router.get('/:id/audio', getAnnouncementAudio);

// Public (guest) read access so people can browse without an account.
router.get('/', listAnnouncements);
router.get('/:id', getAnnouncement);

// Writes require an authenticated account.
router.post('/', authenticate, requireRole('police', 'regional_admin', 'system_admin'), createAnnouncement);
router.post('/:id/retranslate', authenticate, requireRole('regional_admin', 'system_admin'), retranslateAnnouncement);
router.patch('/:id', authenticate, requireRole('regional_admin', 'system_admin'), updateAnnouncement);
router.delete('/:id', authenticate, requireRole('system_admin'), deleteAnnouncement);

export default router;
