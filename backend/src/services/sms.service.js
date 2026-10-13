import { env } from '../config/env.js';

const AT_API_URL = 'https://api.africastalking.com/version1/messaging';
const AT_USERNAME = env.atUsername || 'sandbox';
const AT_API_KEY = env.atApiKey || '';

/**
 * Send SMS via Africa's Talking API
 * In dev mode (no API key), logs the message instead of sending
 */
export async function sendSms(to, message) {
  const recipients = Array.isArray(to) ? to : [to];

  if (!AT_API_KEY) {
    console.log(`[SMS DEV] To: ${recipients.join(', ')} | Message: ${message}`);
    return { status: 'dev_mode', recipients, messageId: `dev-${Date.now()}` };
  }

  try {
    const params = new URLSearchParams();
    params.append('username', AT_USERNAME);
    params.append('to', recipients.map(r => r.startsWith('+') ? r : `+251${r.replace(/^0/, '')}`).join(','));
    params.append('message', message);

    const response = await fetch(AT_API_URL, {
      method: 'POST',
      headers: {
        'apiKey': AT_API_KEY,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });

    const data = await response.json();
    if (data.SMSMessageData && data.SMSMessageData.Recipients) {
      const sent = data.SMSMessageData.Recipients.filter(r => r.status === 'Success');
      return { status: 'sent', sentCount: sent.length, messageId: data.SMSMessageData.MessageId };
    }
    return { status: 'error', error: data };
  } catch (error) {
    console.error('[SMS ERROR]', error.message);
    return { status: 'error', error: error.message };
  }
}

/**
 * Send OTP via SMS
 */
export async function sendOtpSms(phone, code) {
  const message = `Your ZEGA-ALERT verification code is: ${code}. Valid for 10 minutes. Do not share this code.`;
  return sendSms(phone, message);
}

/**
 * Send SOS notification SMS to emergency contacts
 */
export async function sendSosAlertSms(phone, userName, location) {
  const message = `EMERGENCY: ${userName} has triggered an SOS alert. Location: ${location || 'GPS coordinates sent to dispatch'}. If this is a mistake, ignore.`;
  return sendSms(phone, message);
}

/**
 * Send general notification SMS
 */
export async function sendNotificationSms(phone, title, body) {
  const message = `[ZEGA-ALERT] ${title}\n${body}`;
  return sendSms(phone, message);
}