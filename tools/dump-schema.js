const { execSync } = require('child_process');
const path = require('path');
require('dotenv').config();

async function dumpSchema() {
  const outputFile = path.join(__dirname, '../database/schema/schema_full.sql');
  const schemaDir = path.dirname(outputFile);

  if (!require('fs').existsSync(schemaDir)) {
    require('fs').mkdirSync(schemaDir, { recursive: true });
  }

  // Parse DATABASE_URL for pg_dump
  // URL: postgresql://postgres:postgres@localhost:5432/crm_core_local?search_path=crm,public
  const dbUrl = process.env.DATABASE_URL;
  
  if (!dbUrl) {
    console.error('DATABASE_URL not found in .env');
    process.exit(1);
  }

  // Windows: use pg_dump command
  // Note: pg_dump must be in the PATH
  try {
    console.log(`Dumping schema to ${outputFile}...`);
    // --schema-only -n crm
    execSync(`pg_dump "${dbUrl}" --schema-only --no-owner --no-privileges -f "${outputFile}"`);
    console.log('Schema dump completed.');
  } catch (err) {
    console.error('Schema dump failed:', err.message);
    process.exit(1);
  }
}

dumpSchema();
