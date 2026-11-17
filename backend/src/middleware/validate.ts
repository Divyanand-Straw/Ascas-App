import { Request, Response, NextFunction } from 'express';
import { ZodType } from 'zod';
import { sendError } from '../utils/apiResponse';

export interface RequestValidationSchemas {
  body?: ZodType;
  query?: ZodType;
  params?: ZodType;
}

export interface ValidationErrorField {
  field: string;
  message: string;
  location: 'body' | 'query' | 'params';
}

/**
 * Reusable middleware to validate request body, query, and params using Zod schemas.
 * Returns HTTP 400 with errorCode "VALIDATION_ERROR" and field-level details on failure.
 */
export const validateRequest = (schemas: RequestValidationSchemas) => {
  return async (req: Request, res: Response, next: NextFunction): Promise<Response | void> => {
    const details: ValidationErrorField[] = [];

    if (schemas.body) {
      const result = await schemas.body.safeParseAsync(req.body);
      if (!result.success) {
        result.error.issues.forEach((issue) => {
          details.push({
            field: issue.path.join('.') || 'body',
            message: issue.message,
            location: 'body',
          });
        });
      } else {
        req.body = result.data;
      }
    }

    if (schemas.query) {
      const result = await schemas.query.safeParseAsync(req.query);
      if (!result.success) {
        result.error.issues.forEach((issue) => {
          details.push({
            field: issue.path.join('.') || 'query',
            message: issue.message,
            location: 'query',
          });
        });
      } else {
        Object.assign(req.query, result.data);
      }
    }

    if (schemas.params) {
      const result = await schemas.params.safeParseAsync(req.params);
      if (!result.success) {
        result.error.issues.forEach((issue) => {
          details.push({
            field: issue.path.join('.') || 'params',
            message: issue.message,
            location: 'params',
          });
        });
      } else {
        Object.assign(req.params, result.data);
      }
    }

    if (details.length > 0) {
      return sendError(
        res,
        'Invalid request parameters',
        400,
        'VALIDATION_ERROR',
        details
      );
    }

    return next();
  };
};

