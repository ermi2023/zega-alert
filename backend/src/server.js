import http from 'http';
import app from './app.js';
import { env } from './config/env.js';
import { pool } from './config/db.js';
import { io } from './socket/socket.js';
import { setupSocket } from './socket/index.js';

const server = http.createServer(app);
io.attach(server);
setupSocket();

process.on('unhandledRejection', (err) => {
  console.error('[FATAL] unhandled rejection (server kept alive):', err);
});
process.on('uncaughtException', (err) => {
  console.error('[FATAL] uncaught exception (server kept alive):', err);
});

const start = async () => {
  try {
    await pool.query('SELECT 1');
    console.log('[DB] PostgreSQL connected');
  } catch (e) {
    console.error('[DB] Connection failed:', e.message);
    process.exit(1);
  }
  server.listen(env.port, '0.0.0.0', () => {
    console.log(`[SERVER] ${env.appName} running on http://localhost:${env.port}`);
    console.log(`[SOCKET] real-time events attached`);
  });
};

start();
