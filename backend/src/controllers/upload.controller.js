import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { ok, fail } from '../utils/response.js';
import { storageBucket, uploadBufferToStorage } from '../services/firebase.service.js';
import { env } from '../config/env.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const UPLOAD_DIR = path.resolve(__dirname, '..', '..', 'uploads');
export const UPLOAD_URL_PREFIX = '/uploads';

const ALLOWED_EXT = new Set([
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
  'mp4', 'mov', 'webm', 'mp3', 'm4a', 'wav', 'ogg',
  'pdf', 'doc', 'docx', 'txt', 'xlsx', 'csv',
]);

const MIME_EXT = {
  'image/jpeg': 'jpg', 'image/png': 'png', 'image/gif': 'gif', 'image/webp': 'webp',
  'image/bmp': 'bmp',
  'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm',
  'audio/mpeg': 'mp3', 'audio/mp4': 'm4a', 'audio/wav': 'wav', 'audio/ogg': 'ogg',
  'application/pdf': 'pdf',
  'text/plain': 'txt',
};

export function ensureUploadDir() {
  if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// When Firebase Storage is configured, mirror the file there and return its
// public URL; otherwise fall back to the local /uploads static path.
async function storageUrl(file) {
  const bucket = await storageBucket();
  if (bucket) {
    try {
      const buffer = file.buffer || (file.path ? fs.readFileSync(file.path) : null);
      if (!buffer) return null;
      return await uploadBufferToStorage(`uploads/${file.filename}`, buffer, file.mimetype);
    } catch {
      // Try configured Supabase Storage below.
    }
  }

  if (env.supabaseUrl && env.supabaseKey) {
    try {
      const buffer = file.buffer || (file.path ? fs.readFileSync(file.path) : null);
      if (!buffer) return null;

      const storageBucketName = 'zega-alert';
      const objectPath = `uploads/${file.filename}`;
      const headers = {
        apikey: env.supabaseKey,
        Authorization: `Bearer ${env.supabaseKey}`,
        'Content-Type': file.mimetype || 'application/octet-stream',
        'x-upsert': 'true',
      };

      await fetch(`${env.supabaseUrl}/storage/v1/bucket/${storageBucketName}`, {
        method: 'GET',
        headers: { apikey: env.supabaseKey, Authorization: `Bearer ${env.supabaseKey}` },
      }).then(async (response) => {
        if (response.status === 404) {
          await fetch(`${env.supabaseUrl}/storage/v1/bucket`, {
            method: 'POST',
            headers: { ...headers, 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: storageBucketName, name: storageBucketName, public: true }),
          });
        }
      });

      const uploadResponse = await fetch(
        `${env.supabaseUrl}/storage/v1/object/${storageBucketName}/${objectPath}`,
        { method: 'POST', headers, body: buffer },
      );
      if (uploadResponse.ok) {
        return `${env.supabaseUrl}/storage/v1/object/public/${storageBucketName}/${objectPath}`;
      }
    } catch {
      // Production should not silently rely on ephemeral disk storage.
    }
  }

  if (env.nodeEnv === 'production') return null;

  // Local disk remains a development-only fallback.
  return null;
};

const fileMeta = (file, remoteUrl) => ({
  url: remoteUrl || `${UPLOAD_URL_PREFIX}/${file.filename}`,
  original_name: file.originalname,
  size: file.size,
  mime: file.mimetype,
  storage: remoteUrl ? 'persistent' : 'local',
});

export const uploadSingle = async (req, res) => {
  if (!req.file) return fail(res, 'No file uploaded');
  const remote = await storageUrl(req.file);
  if (env.nodeEnv === 'production' && !remote) {
    return fail(res, 'Persistent image storage is not configured', 503);
  }
  ok(res, fileMeta(req.file, remote), 'Uploaded', 201);
};

export const uploadMulti = async (req, res) => {
  if (!req.files || !req.files.length) return fail(res, 'No files uploaded');
  const items = await Promise.all(req.files.map(async (f) => fileMeta(f, await storageUrl(f))));
  if (env.nodeEnv === 'production' && items.some((item) => item.storage === 'local')) {
    return fail(res, 'Persistent image storage is not configured', 503);
  }
  ok(res, items, 'Uploaded', 201);
};

export function fileFilter(req, file, cb) {
  const ext = path.extname(file.originalname).slice(1).toLowerCase();
  if (ALLOWED_EXT.has(ext) || MIME_EXT[file.mimetype]) return cb(null, true);
  cb(new Error('Unsupported file type'));
}

export function filename(req, file, cb) {
  const ext = MIME_EXT[file.mimetype] || path.extname(file.originalname).slice(1).toLowerCase() || 'bin';
  cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}.${ext}`);
}
