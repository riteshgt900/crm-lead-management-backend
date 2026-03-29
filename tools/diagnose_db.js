const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function check() {
  const client = await pool.connect();
  try {
    await client.query('SET search_path = crm, public;');
    
    console.log('--- Migrations Executed ---');
    const res = await client.query('SELECT version FROM schema_migrations ORDER BY executed_at DESC LIMIT 10');
    console.table(res.rows);

    console.log('--- Current Auth Function Definition (Login logic) ---');
    const func = await client.query(`
      SELECT prosrc 
      FROM pg_proc p 
      JOIN pg_namespace n ON p.pronamespace = n.oid 
      WHERE n.nspname = 'crm' AND p.proname = 'fn_auth_operations'
    `);
    
    if (func.rows.length > 0) {
      const src = func.rows[0].prosrc;
      console.log('Includes permissions?', src.includes('permissions'));
      console.log('Includes firstName?', src.includes('firstName'));
      console.log('Includes fullName?', src.includes('full_name'));
    } else {
      console.log('Function not found!');
    }

  } catch (err) {
    console.error('Check failed:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

check();
