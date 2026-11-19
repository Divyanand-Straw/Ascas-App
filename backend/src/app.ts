import express, { Application, Request, Response } from 'express';
import helmet from 'helmet';
import cors, { CorsOptions } from 'cors';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { sendSuccess, sendError } from './utils/apiResponse';
import { getAppHealth, getDatabaseHealth } from './services/health.service';
import v1Router from './routes/v1';

const app: Application = express();

// 1. Security Headers
app.use(helmet());

// 2. Configurable CORS setup
const isProduction = process.env.NODE_ENV === 'production';
const configuredOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((origin) => origin.trim())
  : [];

const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    // Allow non-browser requests (e.g. Flutter mobile native HTTP clients, Postman, curl)
    if (!origin) {
      return callback(null, true);
    }

    // In development mode, allow all origins if not explicitly configured
    if (!isProduction && configuredOrigins.length === 0) {
      return callback(null, true);
    }

    // Allow configured origins or wildcard in development
    if (configuredOrigins.includes('*') || configuredOrigins.includes(origin)) {
      return callback(null, true);
    }

    return callback(new Error(`CORS blocked: Origin '${origin}' is not allowed`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

app.use(cors(corsOptions));

// 3. Body Parsing Middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 4. Versioned API Router (/api/v1)
app.use('/api/v1', v1Router);

// 5. Preserved Backward Compatibility Endpoints (/api/health and /api/health/database)
app.get('/api/health', (_req: Request, res: Response) => {
  const health = getAppHealth();
  return sendSuccess(res, health, 'IVF Patient App API is operational');
});

app.get('/api/health/database', async (_req: Request, res: Response) => {
  try {
    const dbHealth = await getDatabaseHealth();
    return sendSuccess(res, dbHealth, 'Database connection verified successfully');
  } catch (error) {
    return sendError(
      res,
      'Database connection failed',
      503,
      'DATABASE_UNAVAILABLE',
      (error as Error).message
    );
  }
});

// 6. 404 Handler for undefined routes
app.use(notFoundHandler);

// 7. Centralized Error Handler
app.use(errorHandler);

export default app;
