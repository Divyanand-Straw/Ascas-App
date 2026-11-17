import { query, sanitizeErrorMessage } from '../config/database';

export interface AppHealthData {
  service: string;
  status: string;
  uptime: number;
  environment: string;
  timestamp: string;
}

export interface DatabaseHealthData {
  connected: boolean;
  databaseName: string | null;
  databaseTime: string | null;
}

/**
 * Returns system uptime and health information.
 */
export const getAppHealth = (): AppHealthData => {
  return {
    service: 'ivf-patient-backend',
    status: 'healthy',
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
  };
};

/**
 * Executes database ping and returns current database name and timestamp.
 */
export const getDatabaseHealth = async (): Promise<DatabaseHealthData> => {
  try {
    const result = await query(
      'SELECT NOW() AS database_time, current_database() AS database_name;'
    );
    const row = result.rows[0];
    return {
      connected: true,
      databaseName: row.database_name,
      databaseTime: row.database_time,
    };
  } catch (error) {
    const sanitized = sanitizeErrorMessage(
      (error as Error).message || 'Database connection query failed'
    );
    throw new Error(sanitized);
  }
};

