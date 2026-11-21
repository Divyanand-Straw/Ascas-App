import { EmailOtpPurpose } from './auth.types';

export interface IEmailProvider {
  sendOtp(email: string, otp: string, purpose: EmailOtpPurpose): Promise<void>;
}
