import { Request, Response, NextFunction } from 'express';
import { sendError } from '../utils/apiResponse';
import { AppError } from '../utils/errors';
import { sanitizeErrorMessage } from '../config/database';

const getPostgresErrorCode = (error: Error): string | null => {
  const code = (error as Error & { code?: unknown }).code;
  return typeof code === 'string' && /^[0-9A-Z]{5}$/.test(code)
    ? code
    : null;
};

/**
 * Centralized error-handling middleware.
 * Intercepts AppErrors and uncaught exceptions, returning a clean, consistent JSON response.
 */
export const errorHandler = (
  err: Error,
  _req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _next: NextFunction
): Response => {
  // Operational errors created deliberately by the application
  if (err instanceof AppError) {
    return sendError(
      res,
      err.message,
      err.statusCode,
      err.errorCode,
      err.details
    );
  }

  const postgresErrorCode = getPostgresErrorCode(err);
  if (postgresErrorCode || err.name === 'DatabaseError') {
    const schemaError =
      postgresErrorCode === '42703' || postgresErrorCode === '42P01';
    console.error(
      '[Database Error]:',
      postgresErrorCode ? `SQLSTATE ${postgresErrorCode}` : 'database operation failed'
    );
    return sendError(
      res,
      'The request could not be completed. Please try again later.',
      503,
      schemaError ? 'DATABASE_SCHEMA_OUT_OF_DATE' : 'DATABASE_ERROR'
    );
  }

  // Unexpected or unhandled runtime errors
  const isProduction =
    process.env.NODE_ENV === 'production' ||
    process.env.APP_ENV === 'staging';
  const rawMessage = err.message || 'Internal server error';
  const sanitizedMessage = sanitizeErrorMessage(rawMessage);

  console.error(
    '[Unhandled Error]:',
    isProduction ? err.constructor.name : sanitizedMessage
  );

  const clientMessage = isProduction ? 'Internal server error' : sanitizedMessage;

  return sendError(
    res,
    clientMessage,
    500,
    'INTERNAL_SERVER_ERROR'
  );
};

/**
 * 404 handler for unmatched routes.
 */
export const notFoundHandler = (
  req: Request,
  res: Response
): Response => {
  return sendError(
    res,
    `Resource not found: ${req.method} ${req.originalUrl}`,
    404,
    'NOT_FOUND'
  );
};
