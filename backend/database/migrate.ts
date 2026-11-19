import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { pool, checkDatabaseConnection } from '../src/config/database';

dotenv.config();

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

/**
 * Initializes the migration tracking table in PostgreSQL
 */
const initMigrationTable = async (client: any): Promise<void> => {
  const sql = `
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      version VARCHAR(255) NOT NULL UNIQUE,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `;
  await client.query(sql);
};

/**
 * Fetches all migration versions that have already been applied
 */
const getAppliedMigrations = async (client: any): Promise<Set<string>> => {
  const result = await client.query('SELECT version FROM schema_migrations ORDER BY id ASC;');
  return new Set(result.rows.map((row: { version: string }) => row.version));
};

/**
 * Executes pending database migrations inside isolated transactions
 */
const runMigrations = async (): Promise<void> => {
  console.log('🚀 [Migration Runner] Starting database migrations...');

  // Ensure migrations directory exists
  if (!fs.existsSync(MIGRATIONS_DIR)) {
    console.error(`❌ [Migration Runner] Directory not found: ${MIGRATIONS_DIR}`);
    process.exit(1);
  }

  // Get and sort all .sql migration files
  const migrationFiles = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  if (migrationFiles.length === 0) {
    console.log('ℹ️  [Migration Runner] No migration files found in database/migrations.');
    return;
  }

  console.log(`📁 [Migration Runner] Found ${migrationFiles.length} migration file(s).`);

  const client = await pool.connect();

  try {
    // 1. Ensure schema_migrations table exists
    await initMigrationTable(client);

    // 2. Retrieve already applied migrations
    const appliedMigrations = await getAppliedMigrations(client);

    let executedCount = 0;

    for (const file of migrationFiles) {
      if (appliedMigrations.has(file)) {
        console.log(`⏩ [Migration Runner] Skipping already applied: ${file}`);
        continue;
      }

      console.log(`🔄 [Migration Runner] Applying: ${file}...`);
      const filePath = path.join(MIGRATIONS_DIR, file);
      const sql = fs.readFileSync(filePath, 'utf-8');

      // Execute each migration inside a dedicated transaction
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (version) VALUES ($1);', [file]);
        await client.query('COMMIT');
        console.log(`✅ [Migration Runner] Successfully applied: ${file}`);
        executedCount++;
      } catch (err) {
        await client.query('ROLLBACK');
        console.error(`❌ [Migration Runner] Error applying ${file}:`, (err as Error).message);
        throw err;
      }
    }

    if (executedCount === 0) {
      console.log('✨ [Migration Runner] Database is already up to date. No new migrations executed.');
    } else {
      console.log(`🎉 [Migration Runner] Successfully executed ${executedCount} migration(s).`);
    }
  } catch (error) {
    console.error('💥 [Migration Runner] Migration process aborted due to an error.');
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
};

runMigrations();

