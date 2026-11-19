import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  toggleLike,
  getLikes,
  addComment,
  getComments,
  getSocialCounts,
  addPhotos,
  getPhotos,
} from '../controllers/social.controller.js';

const router = Router();

// Public reads
router.get('/:entityType/:entityId/counts', getSocialCounts);
router.get('/:entityType/:entityId/likes', getLikes);
router.get('/:entityType/:entityId/comments', getComments);
router.get('/:entityType/:entityId/photos', getPhotos);

// Authenticated writes
router.post('/:entityType/:entityId/like', authenticate, toggleLike);
router.post('/:entityType/:entityId/comments', authenticate, addComment);
router.post('/:entityType/:entityId/photos', authenticate, addPhotos);

export default router;
