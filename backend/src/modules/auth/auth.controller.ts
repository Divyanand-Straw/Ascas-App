import { Request, Response, NextFunction } from 'express';
import { AuthService } from './auth.service';
import { sendSuccess } from '../../utils/apiResponse';
import { UnauthorizedError } from '../../utils/errors';
import {
  SavePatientProfileInput,
  UpdatePatientProfileInput,
  SendOtpInput,
  VerifyOtpInput,
  RefreshTokenInput,
  LogoutInput,
} from './auth.schema';
import { serializeDateOfBirth } from './auth.types';

export class AuthController {
  private authService: AuthService;

  constructor(authService: AuthService) {
    this.authService = authService;
  }

  /**
   * POST /api/v1/auth/otp/send
   */
  sendOtp = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { phone, purpose } = req.body as SendOtpInput;
      const clientIp = req.ip;

      const result = await this.authService.sendOtp(phone, purpose, clientIp);

      sendSuccess(
        res,
        result,
        this.authService.usesDevelopmentSmsProvider
          ? 'Development verification challenge is ready.'
          : 'Verification code has been dispatched. Please check your SMS.',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  /**
   * POST /api/v1/auth/otp/verify
   */
  verifyOtp = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { challengeId, phone, purpose, otp, deviceInfo } = req.body as VerifyOtpInput;
      const clientIp = req.ip;

      const session = await this.authService.verifyOtp(
        challengeId,
        phone,
        purpose,
        otp,
        deviceInfo,
        clientIp
      );

      sendSuccess(res, session, 'Authentication successful', 200);
    } catch (error) {
      next(error);
    }
  };

  savePatientProfile = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user?.sub;
      if (!userId) {
        return next(new UnauthorizedError('Unauthenticated user', 'UNAUTHORIZED'));
      }

      const {
        firstName,
        lastName,
        dob,
        gender,
        emergencyContact,
        preferredLanguage,
      } = req.body as SavePatientProfileInput;
      const profile = await this.authService.createOrGetPatientProfile(
        userId,
        {
          firstName,
          lastName,
          dob: new Date(`${dob}T00:00:00.000Z`),
          gender,
          emergencyContact,
          preferredLanguage,
        }
      );

      sendSuccess(
        res,
        { ...profile, dob: serializeDateOfBirth(profile.dob) },
        'Patient profile saved successfully',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  updatePatientProfile = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user?.sub;
      if (!userId) {
        return next(new UnauthorizedError('Unauthenticated user', 'UNAUTHORIZED'));
      }
      const { firstName, lastName, dob, gender, preferredLanguage } =
        req.body as UpdatePatientProfileInput;
      const profile = await this.authService.updatePatientProfile(userId, {
        firstName,
        lastName,
        dob: new Date(`${dob}T00:00:00.000Z`),
        gender,
        preferredLanguage,
      });
      sendSuccess(
        res,
        { ...profile, dob: serializeDateOfBirth(profile.dob) },
        'Patient profile updated successfully',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  /**
   * POST /api/v1/auth/token/refresh
   */
  refreshToken = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { refreshToken } = req.body as RefreshTokenInput;
      const clientIp = req.ip;
      const userAgent = req.headers['user-agent'];

      const tokens = await this.authService.refreshTokens(refreshToken, userAgent, clientIp);

      sendSuccess(res, tokens, 'Token refreshed successfully', 200);
    } catch (error) {
      next(error);
    }
  };

  /**
   * POST /api/v1/auth/logout
   */
  logout = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { refreshToken } = req.body as LogoutInput;
      const userId = req.user?.sub;

      if (!userId) {
        return next(new UnauthorizedError('Unauthenticated user', 'UNAUTHORIZED'));
      }

      await this.authService.logout(refreshToken, userId);

      sendSuccess(res, null, 'Logged out successfully', 200);
    } catch (error) {
      next(error);
    }
  };

  /**
   * GET /api/v1/auth/me
   */
  getMe = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user?.sub;
      if (!userId) {
        return next(new Error('Unauthenticated user'));
      }

      const account = await this.authService.getCurrentUser(userId);

      sendSuccess(
        res,
        {
          ...account,
          profile: account.profile
            ? {
                ...account.profile,
                dob: serializeDateOfBirth(account.profile.dob),
              }
            : null,
        },
        'User session active',
        200
      );
    } catch (error) {
      next(error);
    }
  };
}
