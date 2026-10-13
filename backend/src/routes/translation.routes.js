import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  listTranslations, upsertTranslation, deleteTranslation, bulkCreatePlaceholders,
} from '../controllers/translation.controller.js';

const router = Router();
router.use(authenticate);

router.get('/:announcementId', listTranslations);
router.post('/', requireRole('regional_admin', 'system_admin'), upsertTranslation);
router.post('/placeholders', requireRole('regional_admin', 'system_admin'), bulkCreatePlaceholders);
router.delete('/:id', requireRole('system_admin'), deleteTranslation);

export default router;
