import { pool } from '../src/config/db.js';

async function seedPersons() {
  try {
    await pool.query(`
      INSERT INTO wanted_persons (name, age, gender, photo_url, crime_description, danger_level, status)
      VALUES (
        'Dawit Bekele',
        34,
        'male',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=600',
        'Wanted in connection with organized armed robbery and financial fraud in Addis Ababa, Bole sub-city. Considered armed and dangerous. Suspect frequently changes vehicles and was last identified near Edna Mall.',
        'high',
        'wanted'
      );
    `);

    await pool.query(`
      INSERT INTO missing_persons (name, age, gender, photo_url, description, last_seen_address, is_approved, status)
      VALUES (
        'Sara Tadesse',
        24,
        'female',
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=600',
        'Last seen leaving her workplace around 6:30 PM wearing a beige trench coat and black trousers. Has a small birthmark near her left eye. Family and authorities urgently appeal for any verified sightings or information.',
        'Addis Ababa, Bole',
        true,
        'missing'
      );
    `);

    await pool.query(`
      INSERT INTO wanted_persons (name, age, gender, photo_url, crime_description, danger_level, status)
      VALUES (
        'Mulugeta Haile',
        41,
        'male',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=600',
        'Suspect in grand vehicle theft syndicate across Hawassa and Adama. Do not attempt apprehension directly; report immediately to local police or dispatch.',
        'high',
        'wanted'
      );
    `);

    console.log('[SEED] Successfully added sample wanted and missing persons!');
  } catch (err) {
    console.error('[SEED] Error inserting persons:', err);
  } finally {
    await pool.end();
  }
}

seedPersons();
