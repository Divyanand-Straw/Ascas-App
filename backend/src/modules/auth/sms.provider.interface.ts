import { OtpPurpose } from './auth.types';

export interface ISmsProvider {
  sendOtp(phone: string, otp: string, purpose: OtpPurpose): Promise<boolean>;
}
