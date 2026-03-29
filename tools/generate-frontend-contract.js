const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config();

const outputPath = path.join(__dirname, '../docs/frontend-api-contract.json');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  options: '-c search_path=crm,public',
});

async function generateFrontendContract() {
  const client = await pool.connect();

  try {
    const { rows } = await client.query(
      `SELECT crm.fn_contract_operations($1::jsonb) AS res`,
      [JSON.stringify({ operation: 'frontend_contract', data: {} })],
    );

    const envelope = rows[0]?.res;
    if (!envelope || envelope.statusCode !== 200 || !envelope.data) {
      throw new Error('Contract function returned an invalid response');
    }

    fs.writeFileSync(outputPath, JSON.stringify(envelope.data, null, 2), 'utf8');
    console.log(`Frontend contract written to ${outputPath}`);
  } finally {
    client.release();
    await pool.end();
  }
}

generateFrontendContract().catch((error) => {
  console.error('Failed to generate frontend contract:', error);
  process.exitCode = 1;
});
