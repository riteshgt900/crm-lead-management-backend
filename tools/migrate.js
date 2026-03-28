const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function migrate() {
  const migrationsDir = path.join(__dirname, '../database/migrations');
  
  // Ensure table versions exists to track migrations? 
  // No, the requirement says "runs all SQL files in order". 
  // For production-grade simpler approach here is to just run all files.
  // The files use IF NOT EXISTS so they are idempotent.

  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  console.log(`Found ${files.length} migrations.`);

  const client = await pool.connect();

  try {
    for (const file of files) {
      console.log(`Executing migration: ${file}`);
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      await client.query(sql);
    }
    console.log('All migrations completed successfully.');
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
