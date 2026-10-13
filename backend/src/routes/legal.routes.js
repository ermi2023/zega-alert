import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  listLegal, getLegal, listLegalHistory, createLegal, updateLegal, reviewLegal, deleteLegal,
} from '../controllers/legal.controller.js';

const router = Router();
router.use(authenticate);

router.get('/', listLegal);
router.get('/:id', getLegal);
router.get('/:id/history', listLegalHistory);
router.post('/', requireRole('regional_admin', 'system_admin'), createLegal);
router.patch('/:id', requireRole('system_admin'), updateLegal);
router.patch('/:id/review', requireRole('system_admin'), reviewLegal);
router.delete('/:id', requireRole('system_admin'), deleteLegal);

export default router;
