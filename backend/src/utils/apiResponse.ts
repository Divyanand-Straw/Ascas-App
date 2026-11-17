import { Response } from 'express';

export interface PaginationMeta {
  page: number;
  limit: number;
  totalRecords: number;
  totalPages: number;
  hasNextPage: boolean;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  message: string;
  data?: T;
  errorCode?: string;
  details?: unknown;
  meta?: PaginationMeta;
}

/**
 * Sends a standardized success response.
 *
 * Example:
 * {
 *   "success": true,
 *   "message": "Appointments retrieved successfully",
 *   "data": []
 * }
 */
export const sendSuccess = <T>(
  res: Response,
  data?: T,
  message = 'Success',
  statusCode = 200
): Response => {
  const response: ApiResponse<T> = {
    success: true,
    message,
    ...(data !== undefined && { data }),
  };
  return res.status(statusCode).json(response);
};

/**
 * Sends a standardized error response.
 *
 * Example:
 * {
 *   "success": false,
 *   "errorCode": "VALIDATION_ERROR",
 *   "message": "Invalid request parameters",
 *   "details": []
 * }
 */
export const sendError = (
  res: Response,
  message = 'An unexpected error occurred',
  statusCode = 500,
  errorCode = 'INTERNAL_SERVER_ERROR',
  details?: unknown
): Response => {
  const response: ApiResponse = {
    success: false,
    errorCode,
    message,
    ...(details !== undefined && { details }),
  };
  return res.status(statusCode).json(response);
};

/**
 * Sends a standardized paginated response.
 *
 * Example:
 * {
 *   "success": true,
 *   "message": "Appointments retrieved successfully",
 *   "data": [],
 *   "meta": {
 *     "page": 1,
 *     "limit": 10,
 *     "totalRecords": 45,
 *     "totalPages": 5,
 *     "hasNextPage": true
 *   }
 * }
 */
export const sendPaginated = <T>(
  res: Response,
  data: T[],
  meta: PaginationMeta,
  message = 'Data retrieved successfully',
  statusCode = 200
): Response => {
  const response: ApiResponse<T[]> = {
    success: true,
    message,
    data,
    meta,
  };
  return res.status(statusCode).json(response);
};
