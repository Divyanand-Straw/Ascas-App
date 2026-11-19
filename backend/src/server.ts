import dotenv from 'dotenv';

// Load environment variables before importing app and database modules
dotenv.config();

import app from './app';
import { checkDatabaseConnection, pool } from './config/database';

const PORT = Number(process.env.PORT) || 5000;

/**
 * Boots the HTTP server and checks database connectivity
 */
const startServer = async (): Promise<void> => {
  try {
    console.log('🔄 [Server] Checking PostgreSQL database connection...');

    try {
      await checkDatabaseConnection();
    } catch (dbError) {
      // In development, if DB connection fails, warn clearly without crashing the whole process,
      // so developer can still test health check and non-DB endpoints.
      console.warn('⚠️  [Server] Database check failed during startup:', (dbError as Error).message);
      console.warn('ℹ️  [Server] Server will continue starting. Verify your DATABASE_URL in .env.');
    }

    const server = app.listen(PORT, () => {
      console.log(`🚀 [Server] IVF Patient Backend listening on port ${PORT}`);
      console.log(`🩺 [Server] App Health Check:    http://localhost:${PORT}/api/health`);
      console.log(`🗄️  [Server] DB Health Check:     http://localhost:${PORT}/api/health/database`);
      console.log(`✨ [Server] Versioned Health:    http://localhost:${PORT}/api/v1/health`);
      console.log(`🌍 [Server] Mode:                ${process.env.NODE_ENV || 'development'}`);
    });

    // Graceful shutdown handling
    const shutdown = async (signal: string) => {
      console.log(`\n🛑 [Server] Received ${signal}. Initiating graceful shutdown...`);
      server.close(async () => {
        console.log('🔒 [Server] HTTP server closed.');
        try {
          await pool.end();
          console.log('🔒 [Database] Connection pool closed.');
        } catch (err) {
          console.error('❌ [Database] Error closing pool:', err);
        }
        process.exit(0);
      });
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  } catch (error) {
    console.error('❌ [Server] Fatal error during startup:', error);
    process.exit(1);
  }
};

startServer();
