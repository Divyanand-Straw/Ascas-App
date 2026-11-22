import { NextFunction, Request, Response } from 'express';
import { sendSuccess } from '../../utils/apiResponse';
import { EmailAuthService } from './email.auth.service';
import {
  SendEmailOtpInput,
  SendEmailActivationOtpInput,
  SendDeveloperEmailTestOtpInput,
  SendPasswordResetOtpInput,
  VerifyEmailActivationOtpInput,
  VerifyDeveloperEmailTestOtpInput,
  VerifyEmailOtpInput,
} from './email.auth.schema';

export class EmailAuthController {
  constructor(private readonly emailAuthService: EmailAuthService) {}

  sendActivationOtp = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { email } = req.body as SendEmailActivationOtpInput;
      const result = await this.emailAuthService.sendActivationOtp(
        email,
        req.user?.sub,
        req.ip
      );
      sendSuccess(
        res,
        result,
        'Initial email activation code sent.',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  verifyActivationOtp = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { challengeId, email, otp } =
        req.body as VerifyEmailActivationOtpInput;
      const result = await this.emailAuthService.verifyActivationOtp(
        challengeId,
        email,
        otp,
        req.user?.sub
      );
      sendSuccess(res, result, 'Email activation successful.', 200);
    } catch (error) {
      next(error);
    }
  };

  sendOtp = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { email, purpose } = req.body as SendEmailOtpInput;
      const result = await this.emailAuthService.sendOtp(
        email,
        purpose,
        req.user?.sub,
        req.ip
      );
      sendSuccess(
        res,
        result,
        'If the address is eligible, a verification code will be sent.',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  sendPasswordResetOtp = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { phone, email } = req.body as SendPasswordResetOtpInput;
      const result = await this.emailAuthService.sendPasswordResetOtp(
        phone,
        email,
        req.ip
      );
      sendSuccess(
        res,
        result,
        'If the account is eligible, a verification code will be sent to its registered email.',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  verifyOtp = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { challengeId, email, purpose, otp } =
        req.body as VerifyEmailOtpInput;
      const result = await this.emailAuthService.verifyOtp(
        challengeId,
        email,
        purpose,
        otp,
        req.user?.sub
      );
      sendSuccess(res, result, 'Email verification successful.', 200);
    } catch (error) {
      next(error);
    }
  };

  sendDeveloperEmailTestOtp = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { email } = req.body as SendDeveloperEmailTestOtpInput;
      const result =
        await this.emailAuthService.sendDeveloperEmailTestOtp(email, req.ip);
      sendSuccess(
        res,
        result,
        'Brevo accepted the email request for processing.',
        200
      );
    } catch (error) {
      next(error);
    }
  };

  verifyDeveloperEmailTestOtp = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { challengeId, email, otp } =
        req.body as VerifyDeveloperEmailTestOtpInput;
      const result =
        await this.emailAuthService.verifyDeveloperEmailTestOtp(
          challengeId,
          email,
          otp
        );
      sendSuccess(res, result, 'Developer email OTP verified.', 200);
    } catch (error) {
      next(error);
    }
  };
}
