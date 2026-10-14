import { env } from '../config/env.js';

/**
 * Fayda National ID (Ethiopia NIDP) verification integration — spec §4.4.
 *
 * Credential-driven: when FAYDA_API_URL is set, the FIN (12-digit Fayda
 * Identification Number) is checked against the national ID service. When it is
 * blank (default in dev), the caller falls back to auto-approve so the app
 * remains usable without production credentials.
 *
 * The exact NIDP/eKYC contract varies by onboarding, so the response parser
 * accepts the common shapes (verified/status/data/id_token).
 */

const maskId = (id) => {
  const s = String(id || '');
  if (s.length <= 8) return s;
  return `${s.substring(0, 4)}****${s.substring(s.length - 4)}`;
};

export const faydaEnabled = () => env.faydaApiEnabled;

/**
 * Verify a 12-digit Fayda FIN.
 * @returns {Promise<{status:string, verified:boolean, detail?:any, error?:string}>}
 */
export async function verifyFin(fin, { fullName, dateOfBirth } = {}) {
  if (!env.faydaApiEnabled) {
    return { status: 'dev_auto_approve', verified: true, detail: { mode: 'development' } };
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    const response = await fetch(env.faydaApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(env.faydaApiKey ? { Authorization: `Bearer ${env.faydaApiKey}` } : {}),
      },
      body: JSON.stringify({
        fin,
        id_number: fin,
        full_name: fullName || undefined,
        date_of_birth: dateOfBirth || undefined,
      }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
      return { status: 'error', verified: false, error: data?.message || `Fayda API returned ${response.status}`, detail: data };
    }

    const payload = data?.data || data;
    const verified = Boolean(
      payload?.verified ??
      payload?.isVerified ??
      (payload?.status && String(payload.status).toLowerCase() === 'verified') ??
      payload?.id_token ??
      data?.id_token,
    );

    return { status: verified ? 'verified' : 'rejected', verified, detail: payload };
  } catch (error) {
    const reason = error.name === 'AbortError' ? 'Fayda API timed out' : error.message;
    console.error('[FAYDA ERROR]', reason);
    return { status: 'error', verified: false, error: reason };
  }
}

export { maskId };
