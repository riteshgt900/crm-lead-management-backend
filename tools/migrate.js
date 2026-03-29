const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

function getChecksum(sql) {
  return crypto.createHash('sha256').update(sql, 'utf8').digest('hex');
}

async function ensureTrackingTables(client) {
  await client.query('SET search_path = crm, public;');

  await client.query(`
    CREATE TABLE IF NOT EXISTS crm.schema_migrations (
      version VARCHAR(255) PRIMARY KEY,
      executed_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS crm.schema_migration_files (
      filename VARCHAR(255) PRIMARY KEY,
      version_prefix VARCHAR(32) NOT NULL,
      checksum TEXT NOT NULL,
      executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      legacy_source BOOLEAN NOT NULL DEFAULT FALSE
    );
  `);
}

async function reconcileLegacyRows(client, files) {
  const legacyRows = await client.query(`
    SELECT version
    FROM crm.schema_migrations
    ORDER BY version
  `);

  for (const row of legacyRows.rows) {
    const versionPrefix = row.version;
    const matches = files.filter((file) => file.versionPrefix === versionPrefix);
    if (matches.length === 0) {
      continue;
    }

    for (const match of matches) {
      const exists = await client.query(
        'SELECT 1 FROM crm.schema_migration_files WHERE filename = $1',
        [match.filename],
      );

      if (exists.rowCount > 0) {
        continue;
      }

      await client.query(
        `
          INSERT INTO crm.schema_migration_files (filename, version_prefix, checksum, legacy_source)
          VALUES ($1, $2, $3, TRUE)
        `,
        [match.filename, match.versionPrefix, match.checksum],
      );
    }
  }
}

async function migrate() {
  const migrationsDir = path.join(__dirname, '../database/migrations');
  const files = fs
    .readdirSync(migrationsDir)
    .filter((file) => file.endsWith('.sql'))
    .sort()
    .map((filename) => {
      const sql = fs.readFileSync(path.join(migrationsDir, filename), 'utf8');
      return {
        filename,
        versionPrefix: filename.split('__')[0],
        checksum: getChecksum(sql),
        sql,
      };
    });

  console.log(`Found ${files.length} migrations.`);
  const client = await pool.connect();

  try {
    await ensureTrackingTables(client);
    await reconcileLegacyRows(client, files);

    for (const file of files) {
      const existing = await client.query(
        `
          SELECT checksum
          FROM crm.schema_migration_files
          WHERE filename = $1
        `,
        [file.filename],
      );

      if (existing.rowCount > 0) {
        if (existing.rows[0].checksum !== file.checksum) {
          throw new Error(
            `Checksum mismatch for already tracked migration ${file.filename}. ` +
            `Create a new V### migration instead of editing existing history.`,
          );
        }
        continue;
      }

      console.log(`Executing migration: ${file.filename}`);
      await client.query('BEGIN');
      try {
        await client.query(file.sql);
        await client.query(
          `
            INSERT INTO crm.schema_migration_files (filename, version_prefix, checksum)
            VALUES ($1, $2, $3)
          `,
          [file.filename, file.versionPrefix, file.checksum],
        );
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }

    console.log('All migrations completed successfully.');
  } catch (error) {
    console.error('Migration failed:', error);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
