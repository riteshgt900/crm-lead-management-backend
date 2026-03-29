const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function seed() {
  const migrationsDir = path.join(__dirname, '../database/migrations');
  const seedFiles = [
    'V059__seed_workflow_rules.sql', 
    'V060__seed_admin.sql',
    'V066__seed_templates.sql'
  ];

  const client = await pool.connect();

  try {
    for (const file of seedFiles) {
      const filePath = path.join(migrationsDir, file);
      if (fs.existsSync(filePath)) {
        console.log(`Executing seed: ${file}`);
        const sql = fs.readFileSync(filePath, 'utf8');
        await client.query(sql);
      } else {
        console.warn(`Seed file not found: ${file}`);
      }
    }
    console.log('Seeding completed successfully.');
  } catch (err) {
    console.error('Seeding failed:', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
