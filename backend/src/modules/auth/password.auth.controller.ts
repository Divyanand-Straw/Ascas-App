import { NextFunction, Request, Response } from 'express';
import { sendSuccess } from '../../utils/apiResponse';
import { UnauthorizedError } from '../../utils/errors';
import {
  CompletePasswordResetInput,
  EmailPasswordLoginInput,
  SetupRegistrationCredentialsInput,
  SetupPasswordInput,
} from './password.auth.schema';
import { PasswordAuthService } from './password.auth.service';

export class PasswordAuthController {
  constructor(private readonly passwordAuthService: PasswordAuthService) {}

  setupPassword = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { password } = req.body as SetupPasswordInput;
      const userId = req.user?.sub;
      if (!userId) {
        return next(new UnauthorizedError('Authenticated user is required.'));
      }
      await this.passwordAuthService.setupPassword(userId, password);
      sendSuccess(res, null, 'Password setup completed successfully.', 200);
    } catch (error) {
      next(error);
    }
  };

  setupRegistrationCredentials = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { email, password } =
        req.body as SetupRegistrationCredentialsInput;
      const userId = req.user?.sub;
      if (!userId) {
        return next(new UnauthorizedError('Authenticated user is required.'));
      }
      await this.passwordAuthService.setupRegistrationCredentials(
        userId,
        email,
        password
      );
      sendSuccess(
        res,
        null,
        'Registration credentials were configured successfully.',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  login = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { email, password, deviceInfo } =
        req.body as EmailPasswordLoginInput;
      const session = await this.passwordAuthService.login(
        email,
        password,
        deviceInfo,
        req.ip
      );
      sendSuccess(res, session, 'Authentication successful.', 200);
    } catch (error) {
      next(error);
    }
  };

  completePasswordReset = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { resetGrant, newPassword } =
        req.body as CompletePasswordResetInput;
      await this.passwordAuthService.completePasswordReset(
        resetGrant,
        newPassword
      );
      sendSuccess(res, null, 'Password reset completed successfully.', 200);
    } catch (error) {
      next(error);
    }
  };
}
