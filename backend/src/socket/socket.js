import { Server } from 'socket.io';
import { env } from '../config/env.js';

export const io = new Server({
  cors: {
    origin: env.corsOrigins,
    credentials: true,
  },
});
