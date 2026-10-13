import { Router } from 'express';
import multer from 'multer';
import { authenticate } from '../middleware/auth.js';
import { UPLOAD_DIR, uploadSingle, uploadMulti, fileFilter, filename, ensureUploadDir } from '../controllers/upload.controller.js';

ensureUploadDir();

const storage = multer.diskStorage({ destination: UPLOAD_DIR, filename });
export const upload = multer({ storage, fileFilter, limits: { fileSize: 15 * 1024 * 1024 } });

const router = Router();
router.use(authenticate);

router.post('/single', upload.single('file'), uploadSingle);
router.post('/multi', upload.array('files', 10), uploadMulti);

export default router;
