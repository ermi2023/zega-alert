import './middleware/asyncHandler.js';
import express from 'express';
import cors from 'cors';
import { env } from './config/env.js';
import { notFound, errorHandler } from './middleware/errorHandler.js';
import { rateLimit } from './middleware/rateLimit.js';
import { UPLOAD_DIR } from './controllers/upload.controller.js';
import authRoutes from './routes/auth.routes.js';
import reportRoutes from './routes/report.routes.js';
import sosRoutes from './routes/sos.routes.js';
import personRoutes from './routes/person.routes.js';
import announcementRoutes from './routes/announcement.routes.js';
import legalRoutes from './routes/legal.routes.js';
import geofenceRoutes from './routes/geofence.routes.js';
import chatRoutes from './routes/chat.routes.js';
import adminRoutes from './routes/admin.routes.js';
import uploadRoutes from './routes/upload.routes.js';
import feedbackRoutes from './routes/feedback.routes.js';
import callbackRoutes from './routes/callback.routes.js';
import translationRoutes from './routes/translation.routes.js';
import webrtcRoutes from './routes/webrtc.routes.js';
import positionRoutes from './routes/position.routes.js';
import dispatchRoutes from './routes/dispatch.routes.js';
import policyRoutes from './routes/policy.routes.js';
import verificationRoutes from './routes/verification.routes.js';
import podRoutes from './routes/pod.routes.js';
import shareRoutes from './routes/share.routes.js';
import metaRoutes from './routes/meta.routes.js';

const app = express();

app.use(cors({ origin: env.corsOrigins === '*' ? true : env.corsOrigins, credentials: true }));
app.use(express.json({ limit: '5mb' }));
app.use('/uploads', express.static(UPLOAD_DIR));

app.get('/', (req, res) => res.json({ name: env.appName, status: 'running', time: new Date().toISOString() }));
app.get('/health', (req, res) => res.json({ ok: true }));

app.use('/api', rateLimit({ windowMs: 60000, max: 100 }));

app.use('/api/auth', authRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/persons', personRoutes);
app.use('/api/announcements', announcementRoutes);
app.use('/api/legal', legalRoutes);
app.use('/api/geofences', geofenceRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/feedback', feedbackRoutes);
app.use('/api/callbacks', callbackRoutes);
app.use('/api/translations', translationRoutes);
app.use('/api/webrtc', webrtcRoutes);
app.use('/api/position', positionRoutes);
app.use('/api/dispatch', dispatchRoutes);
app.use('/api/policy', policyRoutes);
app.use('/api/verification', verificationRoutes);
app.use('/api/pod', podRoutes);
app.use('/api/share', shareRoutes);
app.use('/api/meta', metaRoutes);

app.use(notFound);
app.use(errorHandler);

export default app;
