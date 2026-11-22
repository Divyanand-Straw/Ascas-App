import { ISmsProvider } from './sms.provider.interface';
import { OtpPurpose } from './auth.types';
import { AppError } from '../../utils/errors';
import {
  assertStagingEnvironment,
  isDevelopmentOtpTerminalLoggingEnabled,
} from '../../config/runtime';
import { maskMobileNumber } from './otp.diagnostics';

const maskDevelopmentPhone = (phone: string): string => {
  const digits = phone.replace(/\D/g, '');
  if (phone.startsWith('+91') && digits.length >= 4) {
    return `+91XXXXXXXX${digits.slice(-4)}`;
  }
  return maskMobileNumber(phone);
};

/**
 * Development / Test SMS Provider. Keeps OTPs in process memory for tests and
 * logs challenge details only when explicitly enabled in local development.
 */
export class DevelopmentSmsProvider implements ISmsProvider {
  // Store sent OTPs in memory for automated test assertion
  public sentMessages: Array<{ phone: string; otp: string; purpose: OtpPurpose; sentAt: Date }> = [];

  getLatestMessage(
    phone: string,
    purpose: OtpPurpose
  ): { otp: string; sentAt: Date } | null {
    for (let index = this.sentMessages.length - 1; index >= 0; index -= 1) {
      const message = this.sentMessages[index];
      if (message.phone === phone && message.purpose === purpose) {
        return { otp: message.otp, sentAt: new Date(message.sentAt) };
      }
    }
    return null;
  }

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Development SMS provider cannot be instantiated in production environments.');
    }
  }

  async sendOtp(phone: string, otp: string, purpose: OtpPurpose): Promise<boolean> {
    if (process.env.NODE_ENV === 'production') {
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

    if (isDevelopmentOtpTerminalLoggingEnabled()) {
      console.info(`Purpose: ${purpose}`);
      console.info(`Phone: ${maskDevelopmentPhone(phone)}`);
      console.info(`OTP: ${otp}`);
    }

    return true;
  }
}

/**
 * Production SMS Provider
 * Enforces an HTTPS gateway URL and credentials (e.g. MSG91, Fast2SMS, Twilio,
 * or a generic HTTP REST gateway).
 * Fails safely if required gateway configuration is not present.
 * NEVER outputs or logs the plaintext OTP to stdout, logs, or error traces.
 */
export class ProductionSmsProvider implements ISmsProvider {
  private readonly gatewayUrl?: string;
  private readonly apiKey?: string;
  private readonly senderId?: string;
  private readonly templateId?: string;
  private readonly timeoutMs: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options?: {
    gatewayUrl?: string;
    apiKey?: string;
    senderId?: string;
    templateId?: string;
    timeoutMs?: number;
    fetchImpl?: typeof fetch;
  }) {
    this.gatewayUrl = options?.gatewayUrl ?? process.env.SMS_GATEWAY_URL;
    this.apiKey = options?.apiKey ?? process.env.SMS_API_KEY;
    this.senderId = options?.senderId ?? process.env.SMS_SENDER_ID ?? 'ASCASI';
    this.templateId = options?.templateId ?? process.env.SMS_TEMPLATE_ID;
    this.timeoutMs = options?.timeoutMs ?? 5000;
    this.fetchImpl = options?.fetchImpl ?? fetch;
  }

  async sendOtp(phone: string, otp: string, purpose: OtpPurpose): Promise<boolean> {
    if (!this.apiKey || !this.gatewayUrl) {
      throw new AppError(
        'Production SMS Gateway is not fully configured.',
        500,
        'SMS_GATEWAY_UNCONFIGURED'
      );
    }

    let gatewayUrl: URL;
    try {
      gatewayUrl = new URL(this.gatewayUrl);
    } catch {
      throw new AppError(
        'Production SMS Gateway URL is invalid.',
        500,
        'SMS_GATEWAY_UNCONFIGURED'
      );
    }
    if (gatewayUrl.protocol !== 'https:') {
      throw new AppError(
        'Production SMS Gateway must use HTTPS.',
        500,
        'SMS_GATEWAY_UNCONFIGURED'
      );
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const payload = {
        recipient: phone,
        code: otp,
        purpose,
        sender: this.senderId,
        templateId: this.templateId,
      };

      const response = await this.fetchImpl(gatewayUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
          'X-Api-Key': this.apiKey,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      if (!response.ok) {
        console.error(
          `❌ [SMS Gateway] Failed delivery to ${maskMobileNumber(phone)} with HTTP status ${response.status}`
        );
        throw new AppError(
          'SMS delivery failed at gateway.',
          502,
          'SMS_GATEWAY_DELIVERY_FAILURE'
        );
      }

      return true;
    } catch (err: unknown) {
      if (err instanceof Error && err.name === 'AbortError') {
        console.error(`⏱️ [SMS Gateway] Request timed out after ${this.timeoutMs}ms.`);
        throw new AppError(
          'SMS gateway request timed out.',
          504,
          'SMS_GATEWAY_TIMEOUT'
        );
      }

      if (err instanceof AppError) {
        throw err;
      }

      console.error('❌ [SMS Gateway] Unexpected error during OTP dispatch.');
      throw new AppError(
        'Failed to send verification SMS via production gateway.',
        500,
        'SMS_GATEWAY_ERROR'
      );
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

/**
 * Factory that selects the appropriate SMS provider based on environment.
 */
type SmsProviderSelection = 'development' | 'production';

type Environment = Readonly<Record<string, string | undefined>>;

const getSmsProviderSelection = (
  env: Environment = process.env
): SmsProviderSelection => {
  if (env.APP_ENV === 'staging') {
    assertStagingEnvironment(env);
    return 'development';
  }

  const environment = env.NODE_ENV;
  if (environment === 'production') {
    return 'production';
  }
  if (environment === 'staging') {
    throw new Error(
      'NODE_ENV=staging is ambiguous; use APP_ENV=staging for mock SMS.'
    );
  }
  if (environment === 'development' || environment === 'test') {
    return 'development';
  }
  return 'production';
};

export const getSmsProviderName = (env: Environment = process.env): string =>
  getSmsProviderSelection(env) === 'development'
    ? 'DevelopmentSmsProvider'
    : 'ProductionSmsProvider';

export const createSmsProvider = (): ISmsProvider =>
  getSmsProviderSelection(process.env) === 'development'
    ? new DevelopmentSmsProvider()
    : new ProductionSmsProvider();
