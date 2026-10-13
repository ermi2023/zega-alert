import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createReport, listReports, getReport, updateReportStatus, myReports, getReportHistory,
} from '../controllers/report.controller.js';

const router = Router();
router.use(authenticate);

router.post('/', createReport);
router.get('/mine', myReports);
router.get('/', listReports);
router.get('/:id', getReport);
router.get('/:id/history', getReportHistory);
router.patch('/:id/status', requireRole('police', 'dispatcher', 'regional_admin', 'system_admin'), updateReportStatus);

export default router;
