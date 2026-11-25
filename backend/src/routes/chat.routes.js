import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import {
  createConversation, myConversations, getMessages, sendMessage, listMessagesForAdmin,
  getEstimatedWait, rateConversation, getUnreadCount, markConversationRead,
} from '../controllers/chat.controller.js';

const router = Router();
router.use(authenticate);

router.get('/wait-time', getEstimatedWait);
router.get('/unread-count', getUnreadCount);
router.patch('/conversations/:id/read', markConversationRead);
router.post('/conversations', createConversation);
router.get('/conversations', myConversations);
router.get('/conversations/:id/messages', getMessages);
router.post('/conversations/:id/messages', sendMessage);
router.post('/conversations/:id/rating', rateConversation);
router.get('/admin/messages', requireRole('system_admin'), listMessagesForAdmin);

export default router;
