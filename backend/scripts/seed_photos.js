import { query } from '../src/config/db.js';

async function seedPhotos() {
  console.log('Seeding extra photos for sample persons...');
  
  // Find Dawit Bekele
  const dawit = await query("SELECT id FROM wanted_persons WHERE name ILIKE '%Dawit Bekele%' LIMIT 1");
  if (dawit.rows.length > 0) {
    const id = dawit.rows[0].id;
    await query("DELETE FROM person_photos WHERE entity_type = 'wanted_person' AND entity_id = $1", [id]);
    await query(`
      INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order)
      VALUES 
        ('wanted_person', $1, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&auto=format&fit=crop&q=80', 0),
        ('wanted_person', $1, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&auto=format&fit=crop&q=80', 1),
        ('wanted_person', $1, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&auto=format&fit=crop&q=80', 2)
    `, [id]);
    console.log('Added 3 photos for Dawit Bekele');
  }

  // Find Sara Tadesse
  const sara = await query("SELECT id FROM missing_persons WHERE name ILIKE '%Sara Tadesse%' LIMIT 1");
  if (sara.rows.length > 0) {
    const id = sara.rows[0].id;
    await query("DELETE FROM person_photos WHERE entity_type = 'missing_person' AND entity_id = $1", [id]);
    await query(`
      INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order)
      VALUES 
        ('missing_person', $1, 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&auto=format&fit=crop&q=80', 0),
        ('missing_person', $1, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80', 1)
    `, [id]);
    console.log('Added 2 photos for Sara Tadesse');
  }

  // Find Mulugeta Haile
  const mulugeta = await query("SELECT id FROM wanted_persons WHERE name ILIKE '%Mulugeta Haile%' LIMIT 1");
  if (mulugeta.rows.length > 0) {
    const id = mulugeta.rows[0].id;
    await query("DELETE FROM person_photos WHERE entity_type = 'wanted_person' AND entity_id = $1", [id]);
    await query(`
      INSERT INTO person_photos (entity_type, entity_id, photo_url, sort_order)
      VALUES 
        ('wanted_person', $1, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&auto=format&fit=crop&q=80', 0),
        ('wanted_person', $1, 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&auto=format&fit=crop&q=80', 1)
    `, [id]);
    console.log('Added 2 photos for Mulugeta Haile');
  }

  console.log('Photo seeding done!');
  process.exit(0);
}

seedPhotos().catch(err => {
  console.error(err);
  process.exit(1);
});
