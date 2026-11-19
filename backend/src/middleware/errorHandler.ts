import { Request, Response, NextFunction } from 'express';
import { sendError } from '../utils/apiResponse';
import { AppError } from '../utils/errors';
import { sanitizeErrorMessage } from '../config/database';

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

  // Unexpected or unhandled runtime errors
  const isProduction = process.env.NODE_ENV === 'production';
  const rawMessage = err.message || 'Internal server error';
  const sanitizedMessage = sanitizeErrorMessage(rawMessage);

  console.error('[Unhandled Error]:', sanitizedMessage);

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
