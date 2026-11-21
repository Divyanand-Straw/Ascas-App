import crypto from 'crypto';
import { Request, Response, Router } from 'express';
import { z } from 'zod';
import { sendError } from '../../utils/apiResponse';
import { validateRequest } from '../../middleware/validate';
import { getDevelopmentOtpViewerConfig } from '../../config/runtime';
import { phoneSchema, otpPurposeSchema } from './auth.schema';
import { AuthService } from './auth.service';

const requestSchema = z.object({
  phone: phoneSchema,
  purpose: otpPurposeSchema,
});

const notFound = (res: Response): Response =>
  sendError(res, 'Resource not found.', 404, 'NOT_FOUND');

const isLocalRequest = (req: Request): boolean => {
  const address = req.socket.remoteAddress?.toLowerCase();
  if (!address) return false;
  const normalized = address.startsWith('::ffff:')
    ? address.slice('::ffff:'.length)
    : address;
  return normalized === '127.0.0.1' || normalized === '::1';
};

const hasViewerSecret = (req: Request, expectedSecret: string): boolean => {
  const authorization = req.get('authorization') ?? '';
  const match = /^Bearer ([A-Za-z0-9_-]+)$/i.exec(authorization);
  if (!match) return false;

  const supplied = Buffer.from(match[1], 'utf8');
  const expected = Buffer.from(expectedSecret, 'utf8');
  return (
    supplied.length === expected.length &&
    supplied.length > 0 &&
    crypto.timingSafeEqual(supplied, expected)
  );
};

export const createDevelopmentOtpViewerRouter = (
  authService: AuthService
): Router => {
  const config = getDevelopmentOtpViewerConfig(process.env);
  if (!config) {
    throw new Error('The development OTP viewer is not enabled.');
  }

  const router = Router();

  router.use((_req, res, next) => {
    res.set({
      'Cache-Control': 'no-store, no-cache, must-revalidate, private',
      Pragma: 'no-cache',
    });
    next();
  });

  router.post(
    '/view',
    validateRequest({ body: requestSchema }),
    async (req, res, next) => {
      try {
        const { phone, purpose } = req.body as z.infer<typeof requestSchema>;
        if (
          !isLocalRequest(req) ||
          !hasViewerSecret(req, config.secret) ||
          !config.allowedPhones.has(phone)
        ) {
          return notFound(res);
        }

        const otp = await authService.getActiveDevelopmentOtp(phone, purpose);
        if (!otp) return notFound(res);

        return res.status(200).json({ otp });
      } catch (error) {
        return next(error);
      }
    }
  );

  return router;
};
