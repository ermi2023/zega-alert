import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  listLegal, getLegal, listLegalHistory, createLegal, updateLegal, reviewLegal, deleteLegal,
} from '../controllers/legal.controller.js';

const router = Router();

// Public (guest) read access.
router.get('/', listLegal);
router.get('/:id', getLegal);
router.get('/:id/history', listLegalHistory);

// Writes require an authenticated account.
router.post('/', authenticate, requireRole('regional_admin', 'system_admin'), createLegal);
router.patch('/:id', authenticate, requireRole('system_admin'), updateLegal);
router.patch('/:id/review', authenticate, requireRole('system_admin'), reviewLegal);
router.delete('/:id', authenticate, requireRole('system_admin'), deleteLegal);

export default router;
