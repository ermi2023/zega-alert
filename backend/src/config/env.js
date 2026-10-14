import 'dotenv/config';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_KEY || process.env.SUPABASE_SERVICE_KEY || '';
// Supabase exposes a standard Postgres connection string. If provided, it takes
// precedence over DATABASE_URL so the same backend can run on Supabase unchanged.
const supabaseDbUrl = process.env.SUPABASE_DB_URL || process.env.SUPABASE_DATABASE_URL || '';

export const env = {
  databaseUrl: supabaseDbUrl || process.env.DATABASE_URL || 'postgres://zega:zega_dev_2026@localhost:5432/zega_alert',
  supabaseUrl,
  supabaseKey,
  supabaseDbUrl,
  supabaseEnabled: Boolean(supabaseUrl && supabaseKey),
  port: parseInt(process.env.PORT || '5000', 10),
  jwtSecret: process.env.JWT_SECRET || 'dev_secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  appName: process.env.APP_NAME || 'ZEGA-ALERT',
  publicBaseUrl: process.env.PUBLIC_BASE_URL || '',
  corsOrigins: !process.env.CORS_ORIGINS || process.env.CORS_ORIGINS === '*'
    ? '*'
    : process.env.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean),
  nodeEnv: process.env.NODE_ENV || 'development',
  // '' = auto-detect from the database host; 'true'/'false' force TLS.
  dbSsl: process.env.DB_SSL || '',
  fcmProjectId: process.env.FCM_PROJECT_ID || '',
  fcmServiceAccount: process.env.FCM_SERVICE_ACCOUNT || '',
  firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '',
  firebaseStorageBucket: process.env.FIREBASE_STORAGE_BUCKET || '',
  atUsername: process.env.AT_USERNAME || 'sandbox',
  atApiKey: process.env.AT_API_KEY || '',
  atSenderId: process.env.AT_SENDER_ID || '',
  // 32-byte key (hex or base64) for AES-256-GCM encryption at rest.
  encryptionKey: process.env.ENCRYPTION_KEY || '',
  // Automatic translation engine (doc 4.3.3 / SD-8). LibreTranslate-compatible.
  translateApiUrl: process.env.TRANSLATE_API_URL || '',
  translateApiKey: process.env.TRANSLATE_API_KEY || '',
  // Fayda National ID verification (spec §4.4). Blank = dev auto-approve.
  faydaApiUrl: process.env.FAYDA_API_URL || '',
  faydaApiKey: process.env.FAYDA_API_KEY || '',
  faydaApiEnabled: Boolean(process.env.FAYDA_API_URL),
};
