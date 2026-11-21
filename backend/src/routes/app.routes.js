import { Router } from 'express';
import { ok } from '../utils/response.js';

const router = Router();
router.get('/version', (req, res) => ok(res, {
  version: '1.0.2',
  url: 'https://github.com/ermi2023/zega-alert/releases/latest/download/zega-alert-release.apk',
  notes: 'Security policy enforcement, dashboard and mobile UX fixes.',
}));
export default router;
