import { Request, Response, NextFunction } from 'express';
import { AuthService } from './auth.service';
import { TokenPayload } from './auth.types';
import { UnauthorizedError, ForbiddenError } from '../../utils/errors';

// Augment Express Request interface to include authenticated user payload
declare global {
  namespace Express {
    interface Request {
      user?: TokenPayload;
    }
  }
}

/**
 * Creates authentication middleware using the provided AuthService instance.
 */
export const createAuthMiddleware = (authService: AuthService) => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next(
        new UnauthorizedError('Missing or malformed Authorization header. Expected Bearer token.', 'UNAUTHORIZED')
      );
    }

    const token = authHeader.substring(7).trim();

    if (!token) {
      return next(new UnauthorizedError('Bearer token is empty.', 'UNAUTHORIZED'));
    }

    try {
      const payload = authService.verifyAccessToken(token);

      if (payload.status === 'SUSPENDED') {
        return next(
          new ForbiddenError('User account has been suspended.', 'ACCOUNT_SUSPENDED')
        );
      }

      req.user = payload;
      return next();
    } catch (error) {
      return next(error);
    }
  };
};
