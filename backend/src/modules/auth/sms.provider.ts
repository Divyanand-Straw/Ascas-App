import { ISmsProvider } from './sms.provider.interface';
import { OtpPurpose } from './auth.types';
import { AppError } from '../../utils/errors';

/**
 * Development / Test SMS Provider
 * Displays the verification OTP solely in the local developer console.
 * Strictly prohibited in production environments.
 */
export class DevelopmentSmsProvider implements ISmsProvider {
  // Store sent OTPs in memory for automated test assertion
  public sentMessages: Array<{ phone: string; otp: string; purpose: OtpPurpose; sentAt: Date }> = [];

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Development SMS provider cannot be instantiated in production environments.');
    }
  }

  async sendOtp(phone: string, otp: string, purpose: OtpPurpose): Promise<boolean> {
    const isProduction = process.env.NODE_ENV === 'production';
    if (isProduction) {
      throw new AppError(
        'Development SMS provider cannot be used in production.',
        500,
        'INSECURE_SMS_PROVIDER_IN_PRODUCTION'
      );
    }

    this.sentMessages.push({
      phone,
      otp,
      purpose,
      sentAt: new Date(),
    });

    console.log(
      `📱 [DEV SMS LOGGER] To: ${phone} | Purpose: ${purpose} | Code: ${otp} | (Expires in 5 minutes)`
    );

    return true;
  }
}

/**
 * Production SMS Provider Placeholder
 * Enforces production SMS gateway configuration (e.g. MSG91, Fast2SMS, Twilio).
 * Fails safely if required gateway credentials are not present.
 */
export class ProductionSmsProvider implements ISmsProvider {
  private apiKey?: string;

  constructor() {
    this.apiKey = process.env.SMS_API_KEY;
  }

  async sendOtp(phone: string, otp: string, purpose: OtpPurpose): Promise<boolean> {
    if (!this.apiKey) {
      throw new AppError(
        'Production SMS Gateway is not configured. Please configure SMS_API_KEY in production.',
        500,
        'SMS_GATEWAY_UNCONFIGURED'
      );
    }

    // In a production implementation with a contracted gateway:
    // Call external REST API (e.g., MSG91 or Fast2SMS) with DLT template ID.
    // Note: NEVER log the OTP to stdout or application logs in production.
    return true;
  }
}

/**
 * Factory that selects the appropriate SMS provider based on environment.
 */
export const createSmsProvider = (): ISmsProvider => {
  const isProduction = process.env.NODE_ENV === 'production';
  return isProduction ? new ProductionSmsProvider() : new DevelopmentSmsProvider();
};
