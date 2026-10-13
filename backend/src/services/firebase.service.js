import { readFileSync } from 'fs';
import { env } from '../config/env.js';
import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging as fbMessaging } from 'firebase-admin/messaging';
import { getFirestore as fbFirestore } from 'firebase-admin/firestore';
import { getStorage as fbStorage } from 'firebase-admin/storage';

// Firebase is entirely optional. When FIREBASE_SERVICE_ACCOUNT is not set
// (or cannot be parsed) every helper below degrades to a safe no-op so the
// platform keeps running on PostgreSQL alone.

let _app = null;
let _enabled = false;
let _attempted = false;

function parseCredential(raw) {
  if (!raw) return null;
  const value = raw.trim();
  if (/\.json$/i.test(value)) {
    try {
      return JSON.parse(readFileSync(value, 'utf8'));
    } catch {
      return null;
    }
  }
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

export function initFirebase() {
  if (_attempted) return _enabled;
  _attempted = true;

  const cred = parseCredential(env.firebaseServiceAccount);
  if (!cred) {
    if (env.firebaseServiceAccount) {
      console.warn('[Firebase] FIREBASE_SERVICE_ACCOUNT present but could not be parsed as JSON');
    } else {
      console.log('[Firebase] not configured — running on PostgreSQL only');
    }
    return false;
  }

  try {
    const options = { credential: cert(cred) };
    if (env.firebaseStorageBucket) options.storageBucket = env.firebaseStorageBucket;
    _app = getApps().length ? getApps()[0] : initializeApp(options);
    _enabled = true;
    console.log(`[Firebase] initialized (project: ${cred.project_id || env.fcmProjectId || 'unknown'})`);
  } catch (e) {
    console.error('[Firebase] init failed:', e.message);
    _enabled = false;
  }
  return _enabled;
}

export function firebaseEnabled() {
  if (!_attempted) initFirebase();
  return _enabled;
}

export function firebaseMessaging() {
  return firebaseEnabled() ? fbMessaging(_app) : null;
}

export function firestore() {
  return firebaseEnabled() ? fbFirestore(_app) : null;
}

export function storageBucket() {
  return firebaseEnabled() && env.firebaseStorageBucket ? fbStorage(_app).bucket() : null;
}

/** Mirror a row into a Firestore collection (hybrid PostgreSQL + Firestore store). */
export async function mirrorSet(collection, id, data) {
  if (!firebaseEnabled()) return false;
  try {
    await firestore()
      .collection(collection)
      .doc(String(id))
      .set({ ...data, _mirroredAt: new Date().toISOString() }, { merge: true });
    return true;
  } catch (e) {
    console.error(`[Firestore] mirror ${collection}/${id} failed:`, e.message);
    return false;
  }
}

export async function mirrorDelete(collection, id) {
  if (!firebaseEnabled()) return false;
  try {
    await firestore().collection(collection).doc(String(id)).delete();
    return true;
  } catch (e) {
    console.error(`[Firestore] delete ${collection}/${id} failed:`, e.message);
    return false;
  }
}

/** Upload a buffer to Firebase Cloud Storage and return its public URL (or null). */
export async function uploadBufferToStorage(remotePath, buffer, contentType) {
  const bucket = storageBucket();
  if (!bucket) return null;
  try {
    const file = bucket.file(remotePath);
    await file.save(buffer, { contentType, resumable: false, metadata: { cacheControl: 'public, max-age=31536000' } });
    try {
      await file.makePublic();
    } catch {
      // Bucket may enforce uniform access; the public URL may still work.
    }
    return `https://storage.googleapis.com/${bucket.name}/${remotePath}`;
  } catch (e) {
    console.error('[Storage] upload failed:', e.message);
    return null;
  }
}

export async function deleteFromStorage(remotePath) {
  const bucket = storageBucket();
  if (!bucket) return false;
  try {
    await bucket.file(remotePath).delete();
    return true;
  } catch {
    return false;
  }
}
