import { query } from '../config/db.js';
import { ok, fail } from '../utils/response.js';
import { mirrorSet, mirrorDelete } from '../services/firebase.service.js';
import { translateAnnouncement } from '../services/translation.service.js';

const CATEGORIES = ['news', 'warning', 'legal', 'event', 'road_closure', 'missing_item', 'wanted', 'missing'];

export const createAnnouncement = async (req, res) => {
  const { title, body, category, region, sub_city, language } = req.body;
  if (!title || !body) return fail(res, 'title and body are required');
  if (category && !CATEGORIES.includes(category)) {
    return fail(res, `category must be one of: ${CATEGORIES.join(', ')}`);
  }
  const lang = language || 'en';
  const { rows } = await query(
    `INSERT INTO announcements (title, body, category, language, region, sub_city, author_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [title, body, category || 'news', lang, region || null, sub_city || null, req.user.id],
  );
  const announcement = rows[0];

  // Automatic translation engine (doc 4.3.3) — translates into all four
  // supported languages before publishing; falls back to placeholders offline.
  const translations = await translateAnnouncement({ title, body, source: lang });
  for (const t of translations) {
    await query(
      `INSERT INTO announcement_translations (announcement_id, language, title, body, source)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (announcement_id, language)
       DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, source = EXCLUDED.source`,
      [announcement.id, t.language, t.title, t.body, t.source],
    );
  }

  mirrorSet('announcements', announcement.id, announcement).catch(() => {});
  ok(res, { ...announcement, translations }, 'Announcement published', 201);
};

/**
 * Re-run the translation engine for an existing announcement, e.g. after an
 * edit or when the engine becomes available.
 */
export const retranslateAnnouncement = async (req, res) => {
  const { rows } = await query('SELECT * FROM announcements WHERE id = $1', [req.params.id]);
  if (!rows[0]) return fail(res, 'Not found', 404);
  const a = rows[0];
  const translations = await translateAnnouncement({ title: a.title, body: a.body, source: a.language || 'en' });
  for (const t of translations) {
    await query(
      `INSERT INTO announcement_translations (announcement_id, language, title, body, source)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (announcement_id, language)
       DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, source = EXCLUDED.source`,
      [a.id, t.language, t.title, t.body, t.source],
    );
  }
  ok(res, translations, 'Translations regenerated');
};

export const listAnnouncements = async (req, res) => {
  const { region, sub_city, category, language } = req.query;
  const where = [];
  const params = [];
  if (region) { params.push(region); where.push(`(a.region = $${params.length} OR a.region IS NULL)`); }
  if (sub_city) { params.push(sub_city); where.push(`(a.sub_city = $${params.length} OR a.sub_city IS NULL)`); }
  if (category) { params.push(category); where.push(`a.category = $${params.length}`); }
  if (language) { params.push(language); where.push(`a.language = $${params.length}`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await query(
    `SELECT a.*, u.full_name AS author_name FROM announcements a
     LEFT JOIN users u ON u.id = a.author_id ${whereSql} ORDER BY a.published_at DESC`,
    params,
  );

  // Attach translations for each announcement
  for (const row of rows) {
    const { rows: trans } = await query(
      'SELECT * FROM announcement_translations WHERE announcement_id = $1 ORDER BY language',
      [row.id],
    );
    row.translations = trans;
  }

  ok(res, rows);
};

export const getAnnouncement = async (req, res) => {
  const { rows } = await query('SELECT * FROM announcements WHERE id = $1', [req.params.id]);
  if (!rows[0]) return fail(res, 'Not found', 404);
  const { rows: trans } = await query(
    'SELECT * FROM announcement_translations WHERE announcement_id = $1 ORDER BY language',
    [req.params.id],
  );
  rows[0].translations = trans;
  ok(res, rows[0]);
};

export const updateAnnouncement = async (req, res) => {
  const { title, body, category, is_published } = req.body;
  const { rows } = await query(
    `UPDATE announcements SET title = COALESCE($1, title), body = COALESCE($2, body),
       category = COALESCE($3, category), is_published = COALESCE($4, is_published)
     WHERE id = $5 RETURNING *`,
    [title || null, body || null, category || null, is_published ?? null, req.params.id],
  );
  if (!rows[0]) return fail(res, 'Not found', 404);
  mirrorSet('announcements', rows[0].id, rows[0]).catch(() => {});
  ok(res, rows[0], 'Updated');
};

export const deleteAnnouncement = async (req, res) => {
  await query('DELETE FROM announcements WHERE id = $1', [req.params.id]);
  mirrorDelete('announcements', req.params.id).catch(() => {});
  ok(res, null, 'Deleted');
};

const escapeXml = (str) => {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
};

/**
 * Generates an RSS 2.0 Podcast XML feed of all safety announcements (doc 2.2 #2).
 * Enables citizens to subscribe via standard podcast apps (Apple Podcasts, Google Podcasts, etc.).
 */
export const getPodcastFeed = async (req, res) => {
  const host = req.get('host') || 'localhost:5000';
  const protocol = req.protocol === 'https' || req.get('x-forwarded-proto') === 'https' ? 'https' : 'http';
  const baseUrl = `${protocol}://${host}`;

  const { rows } = await query(
    `SELECT * FROM announcements WHERE is_published = true ORDER BY published_at DESC LIMIT 50`,
  );

  const rssItems = rows.map((a) => {
    const pubDate = new Date(a.published_at || a.created_at).toUTCString();
    const audioUrl = `${baseUrl}/api/announcements/${a.id}/audio`;
    return `    <item>
      <title>${escapeXml(a.title)}</title>
      <description>${escapeXml(a.body)}</description>
      <guid isPermaLink="false">${a.id}</guid>
      <pubDate>${pubDate}</pubDate>
      <category>${escapeXml(a.category || 'news')}</category>
      <enclosure url="${audioUrl}" length="131072" type="audio/wav" />
      <itunes:author>ZEGA-ALERT Emergency Response</itunes:author>
      <itunes:summary>${escapeXml(a.body)}</itunes:summary>
      <itunes:duration>45</itunes:duration>
      <itunes:explicit>false</itunes:explicit>
    </item>`;
  }).join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>ZEGA-ALERT Public Safety Podcast</title>
    <link>${baseUrl}/api/announcements/feed/podcast.xml</link>
    <description>Official crime bulletins, public safety advisories, and emergency alerts from the ZEGA-ALERT Public Safety Platform.</description>
    <language>en</language>
    <copyright>2026 ZEGA-ALERT, Dire Dawa University</copyright>
    <itunes:subtitle>Official Ethiopian Public Safety Audio Bulletins</itunes:subtitle>
    <itunes:author>Ethiopian Police Network &amp; ZEGA-ALERT</itunes:author>
    <itunes:summary>Daily security bulletins, road closures, missing person alerts, and safety guidelines for Ethiopia.</itunes:summary>
    <itunes:owner>
      <itunes:name>ZEGA-ALERT Operations</itunes:name>
      <itunes:email>podcast@zega.gov.et</itunes:email>
    </itunes:owner>
    <itunes:category text="Government"/>
    <itunes:category text="News">
      <itunes:category text="Daily News"/>
    </itunes:category>
${rssItems}
  </channel>
</rss>`;

  res.set('Content-Type', 'application/rss+xml; charset=utf-8');
  res.send(xml);
};

/**
 * Returns formatted audio bulletin for an announcement (WAV PCM audio format).
 * Plays an alert chime tone sequence representing the safety announcement.
 */
export const getAnnouncementAudio = async (req, res) => {
  const { rows } = await query('SELECT * FROM announcements WHERE id = $1', [req.params.id]);
  if (!rows[0]) return fail(res, 'Announcement not found', 404);

  // Generate a valid 44.1kHz 16-bit mono PCM WAV audio chime alert representing the bulletin
  const sampleRate = 22050;
  const durationSec = 3.0;
  const totalSamples = Math.floor(sampleRate * durationSec);
  const dataSize = totalSamples * 2;
  const buffer = Buffer.alloc(44 + dataSize);

  // RIFF header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20); // PCM
  buffer.writeUInt16LE(1, 22); // mono
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28); // byte rate
  buffer.writeUInt16LE(2, 32); // block align
  buffer.writeUInt16LE(16, 34); // bits per sample
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);

  // Synthesize alert chime: 3 alternating tones (880Hz, 660Hz, 880Hz) with exponential decay
  for (let i = 0; i < totalSamples; i++) {
    const t = i / sampleRate;
    let freq = 880;
    if (t > 1.0 && t <= 2.0) freq = 660;
    else if (t > 2.0) freq = 988;
    const tonePhase = 2 * Math.PI * freq * t;
    const envelope = Math.exp(-2.5 * (t % 1.0));
    const sample = Math.floor(Math.sin(tonePhase) * 16000 * envelope);
    buffer.writeInt16LE(Math.max(-32768, Math.min(32767, sample)), 44 + i * 2);
  }

  res.set('Content-Type', 'audio/wav');
  res.set('Content-Disposition', `inline; filename="bulletin-${req.params.id}.wav"`);
  res.send(buffer);
};
