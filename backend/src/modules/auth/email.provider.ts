import { AppError } from '../../utils/errors';
import {
  getDevelopmentEmailAllowedRecipients,
  getStagingEmailAllowedRecipients,
  isDeveloperEmailOtpTestEnabled,
  isDevelopmentEmailAnyRecipientEnabled,
  isStagingEmailAnyRecipientEnabled,
} from '../../config/runtime';
import { EmailOtpPurpose } from './auth.types';
import { IEmailProvider } from './email.provider.interface';

const BREVO_TRANSACTIONAL_EMAIL_URL = 'https://api.brevo.com/v3/smtp/email';
const EMAIL_ADDRESS_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

const OTP_EMAIL_CONTENT: Record<
  EmailOtpPurpose,
  { subject: string; heading: string; description: string }
> = {
  ACCOUNT_ACTIVATION: {
    subject: 'Verify your email | Thaai Seyali',
    heading: 'Verify your email address',
    description:
      'Use this code to verify the email address for your Thaai Seyali account.',
  },
  EMAIL_CHANGE: {
    subject: 'Verify your new email | Thaai Seyali',
    heading: 'Verify your new email address',
    description:
      'Use this code to confirm the new email address on your Thaai Seyali account.',
  },
  PASSWORD_RESET: {
    subject: 'Reset your password | Thaai Seyali',
    heading: 'Reset your password',
    description:
      'Use this code to reset the password for your Thaai Seyali account.',
  },
  DEVELOPER_EMAIL_TEST: {
    subject: 'Email delivery test | Thaai Seyali',
    heading: 'Developer email delivery test',
    description:
      'Use this code only to verify delivery of the Thaai Seyali developer email test.',
  },
};

const escapeHtml = (value: string): string =>
  value.replace(/[&<>"']/g, (character) => {
    switch (character) {
      case '&':
        return '&amp;';
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '"':
        return '&quot;';
      default:
        return '&#39;';
    }
  });

const buildBrandedOtpEmail = (
  otp: string,
  purpose: EmailOtpPurpose
): { subject: string; htmlContent: string; textContent: string } => {
  const content = OTP_EMAIL_CONTENT[purpose];
  const safeOtp = escapeHtml(otp);
  const htmlContent = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${content.heading}</title>
<style>
@media only screen and (max-width: 600px) {
  .email-shell { padding: 16px 10px !important; }
  .email-content { padding: 30px 20px !important; }
  .otp-code { font-size: 30px !important; letter-spacing: 7px !important; }
}
</style>
</head>
<body style="margin:0;padding:0;background-color:#FFF8F9;font-family:Arial,Helvetica,sans-serif;color:#33252A;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${content.heading} from Thaai Seyali Fertility Care.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFF8F9" style="width:100%;border-collapse:collapse;background-color:#FFF8F9;">
  <tr>
    <td class="email-shell" align="center" style="padding:36px 16px;">
      <table class="email-card" role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;border:1px solid #EDE2E5;border-radius:18px;border-collapse:separate;border-spacing:0;background-color:#FFFFFF;overflow:hidden;">
        <tr>
          <td align="center" bgcolor="#702D45" style="padding:28px 24px;background-color:#702D45;">
            <div style="font-size:23px;line-height:29px;font-weight:700;letter-spacing:2px;color:#FFFFFF;">THAAI SEYALI</div>
            <div style="margin-top:5px;font-size:10px;line-height:16px;font-weight:600;letter-spacing:3px;color:#F7E8EB;">FERTILITY CARE</div>
          </td>
        </tr>
        <tr>
          <td class="email-content" style="padding:40px 44px 30px;">
            <div style="margin:0 0 12px;font-size:11px;line-height:16px;font-weight:700;letter-spacing:1.6px;color:#9A6575;">SECURE ACCOUNT MESSAGE</div>
            <h1 style="margin:0 0 14px;font-size:26px;line-height:34px;font-weight:700;color:#702D45;">${content.heading}</h1>
            <p style="margin:0 0 26px;font-size:15px;line-height:24px;color:#5F5056;">${content.description}</p>
            <p style="margin:0 0 10px;font-size:12px;line-height:18px;font-weight:700;letter-spacing:1px;color:#81747A;">YOUR VERIFICATION CODE</p>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F7E8EB" style="width:100%;border-collapse:separate;border-spacing:0;border:1px solid #E8CAD2;border-radius:12px;background-color:#F7E8EB;">
              <tr>
                <td align="center" style="padding:18px 12px;">
                  <span class="otp-code" style="display:inline-block;font-family:Arial,Helvetica,sans-serif;font-size:34px;line-height:42px;font-weight:700;letter-spacing:9px;padding-left:9px;color:#702D45;">${safeOtp}</span>
                </td>
              </tr>
            </table>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;margin-top:22px;border-collapse:collapse;">
              <tr>
                <td style="padding:0 0 10px;font-size:13px;line-height:21px;color:#5F5056;">
                  This code expires in <strong style="color:#33252A;">5 minutes</strong>. You can request another code after the <strong style="color:#33252A;">30-second resend cooldown</strong> in the app.
                </td>
              </tr>
              <tr>
                <td style="padding:0;font-size:13px;line-height:21px;color:#5F5056;">
                  Never share this code with anyone. If you did not request it, you can safely ignore this email.
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td align="center" bgcolor="#FFFBFA" style="padding:22px 24px;border-top:1px solid #EDE2E5;background-color:#FFFBFA;">
            <div style="font-size:13px;line-height:20px;font-weight:700;color:#702D45;">With care, Thaai Seyali</div>
            <div style="margin-top:5px;font-size:11px;line-height:18px;color:#81747A;">Fertility Care</div>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>`;
  const textContent = [
    'THAAI SEYALI | FERTILITY CARE',
    '',
    content.heading,
    content.description,
    '',
    'YOUR VERIFICATION CODE',
    otp,
    '',
    'This code expires in 5 minutes. You can request another code after the 30-second resend cooldown in the app.',
    'Never share this code with anyone. If you did not request it, you can safely ignore this email.',
    '',
    'With care, Thaai Seyali',
    'Fertility Care',
  ].join('\n');

  return {
    subject: content.subject,
    htmlContent,
    textContent,
  };
};

const sanitizeProviderMessage = (
  message: string,
  sensitiveValues: readonly string[]
): string => {
  let sanitized = message.replace(/[\r\n\t]+/g, ' ').replace(/\s+/g, ' ').trim();
  for (const value of sensitiveValues) {
    if (value) {
      sanitized = sanitized.split(value).join('[redacted]');
    }
  }
  sanitized = sanitized
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[redacted email]')
    .replace(/\b\d{4,}\b/g, '[redacted]')
    .replace(
      /\b(authorization)\s*[:=]\s*(?:bearer\s+)?[^,\s;"']+/gi,
      '$1=[redacted]'
    )
    .replace(/\b(bearer)\s+[^,\s;"']+/gi, '$1 [redacted]')
    .replace(
      /\b(api[-_ ]?key|[\w-]*token|password|secret)\s*[:=]\s*["']?[^,\s;"']+/gi,
      '$1=[redacted]'
    )
    .slice(0, 240);
  return sanitized || 'Brevo returned no safe diagnostic message.';
};

export class DevelopmentEmailProvider implements IEmailProvider {
  public readonly sentMessages: Array<{
    email: string;
    otp: string;
    purpose: EmailOtpPurpose;
    sentAt: Date;
  }> = [];

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Development email provider cannot be used in production.');
    }
  }

  async sendOtp(
    email: string,
    otp: string,
    purpose: EmailOtpPurpose
  ): Promise<void> {
    this.sentMessages.push({ email, otp, purpose, sentAt: new Date() });
  }
}

export interface BrevoEmailProviderOptions {
  apiKey?: string;
  senderEmail?: string;
  senderName?: string;
  allowedRecipients?: readonly string[];
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

export class BrevoEmailProvider implements IEmailProvider {
  private readonly apiKey?: string;
  private readonly senderEmail?: string;
  private readonly senderName?: string;
  private readonly allowedRecipients?: ReadonlySet<string>;
  private readonly timeoutMs: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options?: BrevoEmailProviderOptions) {
    this.apiKey = options?.apiKey ?? process.env.BREVO_API_KEY;
    this.senderEmail = options?.senderEmail ?? process.env.BREVO_SENDER_EMAIL;
    this.senderName = options?.senderName ?? process.env.BREVO_SENDER_NAME;
    this.allowedRecipients = options?.allowedRecipients
      ? new Set(
          options.allowedRecipients.map((email) => email.trim().toLowerCase())
        )
      : undefined;
    this.timeoutMs = options?.timeoutMs ?? 5000;
    this.fetchImpl = options?.fetchImpl ?? fetch;
  }

  private getConfiguration(): {
    apiKey: string;
    senderEmail: string;
    senderName: string;
  } {
    const apiKey = this.apiKey;
    const senderEmail = this.senderEmail?.trim().toLowerCase();
    const senderName = this.senderName?.trim();
    if (
      !apiKey ||
      /\s/.test(apiKey) ||
      /^['"]|['"]$/.test(apiKey) ||
      !senderEmail ||
      !EMAIL_ADDRESS_PATTERN.test(senderEmail) ||
      !senderName ||
      (this.allowedRecipients && this.allowedRecipients.size === 0)
    ) {
      throw new AppError(
        'Transactional email delivery is not configured.',
        503,
        'EMAIL_PROVIDER_UNCONFIGURED'
      );
    }
    return {
      apiKey,
      senderEmail,
      senderName,
    };
  }

  assertConfigured(): void {
    this.getConfiguration();
  }

  private async getAcceptedMessageId(
    response: Response
  ): Promise<string | undefined> {
    if (
      !response.headers
        .get('content-type')
        ?.toLowerCase()
        .includes('application/json')
    ) {
      return undefined;
    }

    let responseBody: unknown;
    try {
      responseBody = await response.json();
    } catch (error: unknown) {
      if (error instanceof SyntaxError || error instanceof TypeError) {
        return undefined;
      }
      throw error;
    }

    if (
      typeof responseBody !== 'object' ||
      responseBody === null ||
      !('messageId' in responseBody)
    ) {
      return undefined;
    }
    const messageId = responseBody.messageId;
    return typeof messageId === 'string' &&
      /^[A-Za-z0-9_.@:<>\-]{1,256}$/.test(messageId)
      ? messageId
      : undefined;
  }

  private async createDeliveryError(
    response: Response,
    apiKey: string,
    otp: string
  ): Promise<AppError> {
    let responseBody: unknown;
    let responseText = '';
    try {
      responseText = await response.text();
      responseBody = JSON.parse(responseText) as unknown;
    } catch (error: unknown) {
      if (!(error instanceof SyntaxError)) {
        responseBody = null;
      }
    }

    const body =
      typeof responseBody === 'object' && responseBody !== null
        ? (responseBody as Record<string, unknown>)
        : {};
    const rawCode = typeof body.code === 'string' ? body.code : '';
    const normalizedCode = rawCode.toLowerCase();
    const providerCode =
      /^[a-zA-Z0-9_-]{1,64}$/.test(rawCode) &&
      sanitizeProviderMessage(normalizedCode, [apiKey, otp]) === normalizedCode
        ? normalizedCode
        : undefined;
    const rawMessage = typeof body.message === 'string' ? body.message : '';
    const safeProviderMessage = sanitizeProviderMessage(
      rawMessage || (responseText && !responseBody ? responseText : ''),
      [apiKey, otp]
    );
    const senderRejected =
      /(sender|from).*(unverified|not verified|not valid|invalid|not allowed|unauthori[sz]ed)|(?:unverified|not verified).*(sender|from)/i.test(
        rawMessage
      );
    const authenticationRejected =
      response.status === 401 ||
      providerCode === 'unauthorized' ||
      providerCode === 'invalid_api_key';
    const permissionDenied =
      response.status === 403 || providerCode === 'permission_denied';
    let code = 'EMAIL_PROVIDER_DELIVERY_FAILURE';
    let message = `Brevo rejected the transactional email request (HTTP ${response.status}): ${safeProviderMessage}`;
    if (authenticationRejected) {
      code = 'BREVO_AUTHENTICATION_FAILED';
      message = `Brevo rejected the API request (HTTP ${response.status}): ${safeProviderMessage}`;
    } else if (senderRejected) {
      code = 'BREVO_SENDER_REJECTED';
      message = `Brevo rejected the configured sender (HTTP ${response.status}): ${safeProviderMessage}`;
    } else if (permissionDenied) {
      code = 'BREVO_PERMISSION_DENIED';
      message = `Brevo denied this API operation (HTTP ${response.status}): ${safeProviderMessage}`;
    } else if (response.status === 429) {
      code = 'BREVO_RATE_LIMITED';
      message = `Brevo rate-limited transactional email delivery: ${safeProviderMessage}`;
    }
    const retryAfterSeconds =
      response.status === 429
        ? this.getRetryAfterSeconds(response)
        : undefined;

    return new AppError(message, response.status, code, {
      provider: 'Brevo',
      source: 'email_provider',
      httpStatus: response.status,
      providerCode,
      providerMessage: safeProviderMessage,
      ...(retryAfterSeconds === undefined ? {} : { retryAfterSeconds }),
    });
  }

  private getRetryAfterSeconds(response: Response): number | undefined {
    const retryAfter = response.headers.get('retry-after')?.trim();
    if (!retryAfter) return undefined;
    if (/^\d+$/.test(retryAfter)) {
      const seconds = Number(retryAfter);
      return Number.isSafeInteger(seconds) ? Math.max(1, seconds) : undefined;
    }

    const retryAt = Date.parse(retryAfter);
    if (!Number.isFinite(retryAt)) return undefined;
    return Math.max(1, Math.ceil((retryAt - Date.now()) / 1000));
  }

  async sendOtp(
    email: string,
    otp: string,
    purpose: EmailOtpPurpose
  ): Promise<void> {
    const { apiKey, senderEmail, senderName } = this.getConfiguration();

    const normalizedRecipient = email.trim().toLowerCase();
    if (!EMAIL_ADDRESS_PATTERN.test(normalizedRecipient)) {
      throw new AppError(
        'A valid recipient email address is required.',
        400,
        'INVALID_EMAIL'
      );
    }
    if (
      this.allowedRecipients &&
      !this.allowedRecipients.has(normalizedRecipient)
    ) {
      throw new AppError(
        'Email delivery is restricted to configured recipients.',
        403,
        'EMAIL_RECIPIENT_NOT_ALLOWED'
      );
    }
    const recipient = normalizedRecipient;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const emailContent = buildBrandedOtpEmail(otp, purpose);
      const response = await this.fetchImpl(BREVO_TRANSACTIONAL_EMAIL_URL, {
        method: 'POST',
        headers: {
          accept: 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          sender: {
            email: senderEmail,
            name: senderName,
          },
          to: [{ email: recipient }],
          ...emailContent,
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        throw await this.createDeliveryError(response, apiKey, otp);
      }

      const messageId = await this.getAcceptedMessageId(response);
      if (
        process.env.NODE_ENV === 'development' &&
        (process.env.APP_ENV === 'staging' ||
          isDeveloperEmailOtpTestEnabled(process.env))
      ) {
        console.info(
          `[Brevo] Transactional message accepted for processing (HTTP ${response.status}${messageId ? `, messageId=${messageId}` : ''}).`
        );
      }
    } catch (error: unknown) {
      if (error instanceof AppError) {
        throw error;
      }
      if (
        controller.signal.aborted ||
        (error instanceof Error && error.name === 'AbortError')
      ) {
        throw new AppError(
          'Transactional email provider timed out.',
          504,
          'EMAIL_PROVIDER_TIMEOUT'
        );
      }
      throw new AppError(
        'Transactional email provider is unavailable.',
        502,
        'EMAIL_PROVIDER_ERROR'
      );
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

export const createEmailProvider = (): IEmailProvider => {
  if (process.env.APP_ENV === 'staging') {
    const allowAnyRecipient = isStagingEmailAnyRecipientEnabled(process.env);
    const allowedRecipients = allowAnyRecipient
      ? undefined
      : getStagingEmailAllowedRecipients(process.env);
    const provider = new BrevoEmailProvider({
      apiKey: process.env.BREVO_API_KEY,
      senderEmail: process.env.BREVO_SENDER_EMAIL,
      senderName: process.env.BREVO_SENDER_NAME,
      allowedRecipients,
    });
    provider.assertConfigured();
    return provider;
  }

  if (
    process.env.APP_ENV === 'development' &&
    isDeveloperEmailOtpTestEnabled(process.env)
  ) {
    const allowAnyRecipient =
      isDevelopmentEmailAnyRecipientEnabled(process.env);
    const allowedRecipients = allowAnyRecipient
      ? undefined
      : getDevelopmentEmailAllowedRecipients(process.env);
    const provider = new BrevoEmailProvider({
      apiKey: process.env.BREVO_API_KEY,
      senderEmail: process.env.BREVO_SENDER_EMAIL,
      senderName: process.env.BREVO_SENDER_NAME,
      allowedRecipients,
    });
    provider.assertConfigured();
    return provider;
  }

  if (process.env.NODE_ENV === 'production') {
    return new BrevoEmailProvider();
  }
  if (process.env.NODE_ENV === 'staging') {
    throw new Error(
      'NODE_ENV=staging is ambiguous; use APP_ENV=staging with explicit staging configuration.'
    );
  }
  if (
    process.env.NODE_ENV === 'development' ||
    process.env.NODE_ENV === 'test'
  ) {
    return new DevelopmentEmailProvider();
  }
  return new BrevoEmailProvider();
};
