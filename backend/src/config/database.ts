import { Pool, PoolConfig } from 'pg';
import { loadBackendEnvironment } from './environment';
import { resolveDatabaseUrl } from './runtime';

loadBackendEnvironment();

const databaseUrl = resolveDatabaseUrl(process.env);

/**
 * Sanitizes connection strings and passwords from error messages to prevent credential leaks.
 */
export const sanitizeErrorMessage = (message: string): string => {
  if (!message) return 'Unknown error';
  // Redact password from URIs: postgresql://user:password@host -> postgresql://user:****@host
  return message.replace(/(postgres(?:ql)?:\/\/[^:]+:)([^@]+)(@)/gi, '$1****$3');
};

const poolConfig: PoolConfig = {
  connectionString: databaseUrl,
};

const isLocalhost = Boolean(
  databaseUrl && (databaseUrl.includes('localhost') || databaseUrl.includes('127.0.0.1'))
);

// Supabase PostgreSQL requires an SSL connection for remote instances.
// Supabase uses its own internal certificate authority chain for direct database endpoints.
// We configure SSL so that rejectUnauthorized is false by default for Supabase compatibility,
// but can be strictly enforced (rejectUnauthorized: true) if DB_SSL_REJECT_UNAUTHORIZED=true is set in .env.
if (databaseUrl && !isLocalhost) {
  const rejectUnauthorized = process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true';
  poolConfig.ssl = {
    rejectUnauthorized,
  };
}

/**
 * Shared PostgreSQL connection pool instance
 */
export const pool = new Pool(poolConfig);

// Catch unexpected errors on idle pool clients to prevent unhandled process crashes
pool.on('error', (err: Error) => {
  console.error('[Database Pool Error]:', sanitizeErrorMessage(err.message));
});

/**
 * Reusable query execution helper function
 */
export const query = async (text: string, params?: unknown[]) => {
  if (!databaseUrl || databaseUrl === 'your_supabase_connection_string') {
    throw new Error('DATABASE_URL is not configured in .env');
  }

  if (!databaseUrl.startsWith('postgresql://') && !databaseUrl.startsWith('postgres://')) {
    throw new Error(
      'DATABASE_URL format is invalid. It must be a PostgreSQL connection string starting with "postgresql://" or "postgres://", not an HTTP/HTTPS URL.'
    );
  }

  return pool.query(text, params);
};

/**
 * Verifies connectivity to the PostgreSQL database.
 * Returns true if connection succeeds, false if DATABASE_URL is not configured.
 * Throws a sanitized error if connection fails.
 */
export const checkDatabaseConnection = async (): Promise<boolean> => {
  if (!databaseUrl || databaseUrl === 'your_supabase_connection_string') {
    console.warn('⚠️  [Database] DATABASE_URL is not configured or using placeholder in .env');
    console.warn('ℹ️  [Database] Add your Supabase PostgreSQL connection string to .env to enable database operations.');
    return false;
  }

  if (!databaseUrl.startsWith('postgresql://') && !databaseUrl.startsWith('postgres://')) {
    const invalidFormatMsg =
      'DATABASE_URL in .env is not a PostgreSQL URI. You provided an HTTP/HTTPS URL. Please use your Supabase PostgreSQL connection string (postgresql://postgres:[password]@...).';
    console.warn(`⚠️  [Database] ${invalidFormatMsg}`);
    throw new Error(invalidFormatMsg);
  }

  try {
    const client = await pool.connect();
    try {
      const result = await client.query('SELECT NOW() AS database_time, current_database() AS database_name;');
      console.log('✅ [Database] PostgreSQL connected successfully.');
      console.log(`📦 [Database] Database: "${result.rows[0].database_name}" | Server Time: ${result.rows[0].database_time}`);
      return true;
    } finally {
      client.release();
    }
  } catch (error) {
    const sanitized = sanitizeErrorMessage((error as Error).message);
    console.error('❌ [Database] Connection check failed:', sanitized);
    throw new Error(sanitized);
  }
};

export default pool;
