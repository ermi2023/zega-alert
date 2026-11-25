import { query } from '../src/config/db.js';

async function seedNews() {
  console.log('Seeding news and road closures matching screenshot...');

  // 1. Delete existing news if needed or just add/update
  await query(`DELETE FROM announcements WHERE title IN ('Major Closure on Bole Road', 'Federal Police Announce New Community Safety Initiative', 'Critical Security Advisory: Cyber Phishing Awareness')`);

  // Item 1: Road Closure with start and end map coordinates
  await query(`
    INSERT INTO announcements (
      title, body, category, is_published, published_at,
      badge_label, badge_color, source_label,
      start_time_label, detour_info,
      closure_start_lat, closure_start_lng, closure_end_lat, closure_end_lng
    ) VALUES (
      'Major Closure on Bole Road',
      'Due to ongoing road construction and upcoming municipal events, the main arterial route on Bole Road will be closed from Meskel Square to the airport junction starting at 18:00 EAT today.',
      'road_closure',
      true,
      now() - interval '1 hour',
      'TRAFFIC ALERT',
      '#F59E0B',
      'Traffic Police Department',
      'Starts in 2 hrs',
      'Detour active',
      9.0107, 38.7612, 8.9950, 38.7850
    )
  `);

  // Item 2: News with officer image
  await query(`
    INSERT INTO announcements (
      title, body, category, is_published, published_at,
      badge_label, badge_color, source_label, image_url
    ) VALUES (
      'Federal Police Announce New Community Safety Initiative',
      'A comprehensive neighborhood watch program will be rolled out across key sub-cities starting next month to foster better community-police relations and proactive incident reporting.',
      'news',
      true,
      now() - interval '2 hours',
      'PRESS RELEASE',
      '#1E3A8A',
      'ZEGA-ALERT Media Desk',
      'https://images.unsplash.com/photo-1582750433449-648ed127bb54?w=800&auto=format&fit=crop&q=80'
    )
  `);

  // Item 3: Advisory with tech/cyber image
  await query(`
    INSERT INTO announcements (
      title, body, category, is_published, published_at,
      badge_label, badge_color, source_label, image_url
    ) VALUES (
      'Critical Security Advisory: Cyber Phishing Awareness',
      'Citizens are advised to remain vigilant against phishing messages requesting mobile banking OTP credentials or personal verification codes.',
      'warning',
      true,
      now() - interval '5 hours',
      'ADVISORY',
      '#B45309',
      'Cyber Security Command',
      'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=800&auto=format&fit=crop&q=80'
    )
  `);

  console.log('Seeded news & road closure items successfully!');
  process.exit(0);
}

seedNews().catch(err => {
  console.error(err);
  process.exit(1);
});
