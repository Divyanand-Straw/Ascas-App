import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  BrevoEmailProvider,
  createEmailProvider,
  DevelopmentEmailProvider,
} from '../src/modules/auth/email.provider';
import { AppError } from '../src/utils/errors';

describe('BrevoEmailProvider', () => {
  it('selects the development provider only for explicit development and test environments', () => {
    const previousEnv = process.env.NODE_ENV;
    const previousAppEnv = process.env.APP_ENV;
    try {
      delete process.env.APP_ENV;
      process.env.NODE_ENV = 'development';
      assert.ok(createEmailProvider() instanceof DevelopmentEmailProvider);
      process.env.NODE_ENV = 'test';
      assert.ok(createEmailProvider() instanceof DevelopmentEmailProvider);
      process.env.NODE_ENV = 'staging';
      assert.throws(
        () => createEmailProvider(),
        /APP_ENV=staging with explicit staging configuration/
      );
      process.env.NODE_ENV = 'production';
      assert.ok(createEmailProvider() instanceof BrevoEmailProvider);
    } finally {
      if (previousEnv === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = previousEnv;
      if (previousAppEnv === undefined) delete process.env.APP_ENV;
      else process.env.APP_ENV = previousAppEnv;
    }
  });

  it('sends transactional email through Brevo without exposing provider credentials', async () => {
    let requestUrl = '';
    let requestInit: RequestInit | undefined;
    const apiKey = 'test-brevo-api-key';
    const provider = new BrevoEmailProvider({
      apiKey,
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async (input, init) => {
        requestUrl = String(input);
        requestInit = init;
        return Response.json(
          { messageId: '<brevo-message-123@example.com>' },
          { status: 201 }
        );
      },
    });

    await provider.sendOtp(
      ' Patient@Example.com ',
      '123456',
      'ACCOUNT_ACTIVATION'
    );

    assert.equal(requestUrl, 'https://api.brevo.com/v3/smtp/email');
    assert.equal(requestInit?.method, 'POST');
    assert.equal(
      (requestInit?.headers as Record<string, string>)['api-key'],
      apiKey
    );
    const payload = JSON.parse(String(requestInit?.body)) as {
      sender: { email: string; name: string };
      to: Array<{ email: string }>;
      subject: string;
      htmlContent: string;
      textContent: string;
    };
    assert.deepEqual(payload.sender, {
      email: 'no-reply@example.com',
      name: 'Thaai Seyali',
    });
    assert.deepEqual(payload.to, [{ email: 'patient@example.com' }]);
    assert.equal(payload.subject, 'Verify your email | Thaai Seyali');
    assert.match(payload.htmlContent, /THAAI SEYALI/);
    assert.match(payload.htmlContent, /#702D45/);
    assert.match(payload.htmlContent, /#F7E8EB/);
    assert.match(payload.htmlContent, /@media only screen and \(max-width: 600px\)/);
    assert.match(payload.htmlContent, /role="presentation"/);
    assert.match(payload.htmlContent, /expires in <strong[^>]*>5 minutes<\/strong>/);
    assert.match(payload.htmlContent, /30-second resend cooldown/);
    assert.match(payload.htmlContent, /123456/);
    assert.match(payload.textContent, /THAAI SEYALI/);
    assert.match(payload.textContent, /123456/);
    assert.match(payload.textContent, /expires in 5 minutes/);
    assert.match(payload.textContent, /Never share this code/);
  });

  it('uses the branded layout and purpose-specific copy for each OTP email', async () => {
    const cases = [
      {
        purpose: 'EMAIL_CHANGE',
        subject: 'Verify your new email | Thaai Seyali',
        heading: 'Verify your new email address',
      },
      {
        purpose: 'PASSWORD_RESET',
        subject: 'Reset your password | Thaai Seyali',
        heading: 'Reset your password',
      },
      {
        purpose: 'DEVELOPER_EMAIL_TEST',
        subject: 'Email delivery test | Thaai Seyali',
        heading: 'Developer email delivery test',
      },
    ] as const;
    const messages: Array<{
      subject: string;
      htmlContent: string;
      textContent: string;
    }> = [];
    const provider = new BrevoEmailProvider({
      apiKey: 'synthetic-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async (_input, init) => {
        messages.push(
          JSON.parse(String(init?.body)) as {
            subject: string;
            htmlContent: string;
            textContent: string;
          }
        );
        return new Response(null, { status: 201 });
      },
    });

    for (const { purpose } of cases) {
      await provider.sendOtp('patient@example.com', '123456', purpose);
    }

    assert.equal(messages.length, cases.length);
    for (const [index, { subject, heading }] of cases.entries()) {
      const message = messages[index];
      assert.equal(message.subject, subject);
      assert.match(message.htmlContent, new RegExp(heading));
      assert.match(message.htmlContent, /THAAI SEYALI/);
      assert.match(message.htmlContent, /#702D45/);
      assert.match(message.textContent, new RegExp(heading));
      assert.match(message.textContent, /123456/);
      assert.match(message.textContent, /30-second resend cooldown/);
    }
  });

  it('passes the effective environment key unchanged to the api-key header', async () => {
    const previousApiKey = process.env.BREVO_API_KEY;
    const runtimeApiKey = 'runtime-key_0123456789.XY+/=';
    process.env.BREVO_API_KEY = runtimeApiKey;
    let requestInit: RequestInit | undefined;

    try {
      const provider = new BrevoEmailProvider({
        senderEmail: 'no-reply@example.com',
        senderName: 'Thaai Seyali',
        fetchImpl: async (_input, init) => {
          requestInit = init;
          return new Response(null, { status: 201 });
        },
      });

      for (const purpose of [
        'EMAIL_CHANGE',
        'PASSWORD_RESET',
        'DEVELOPER_EMAIL_TEST',
      ] as const) {
        await provider.sendOtp('patient@example.com', '123456', purpose);
      }
      assert.equal(
        (requestInit?.headers as Record<string, string>)['api-key'],
        runtimeApiKey
      );
    } finally {
      if (previousApiKey === undefined) delete process.env.BREVO_API_KEY;
      else process.env.BREVO_API_KEY = previousApiKey;
    }
  });

  it('rejects whitespace or quoted API keys instead of silently changing them', async () => {
    let dispatchCount = 0;
    for (const apiKey of [' synthetic-key', 'synthetic-key ', '"synthetic-key"']) {
      const provider = new BrevoEmailProvider({
        apiKey,
        senderEmail: 'no-reply@example.com',
        senderName: 'Thaai Seyali',
        fetchImpl: async () => {
          dispatchCount += 1;
          return new Response(null, { status: 201 });
        },
      });

      await assert.rejects(
        () =>
          provider.sendOtp(
            'patient@example.com',
            '123456',
            'PASSWORD_RESET'
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'EMAIL_PROVIDER_UNCONFIGURED'
      );
    }
    assert.equal(dispatchCount, 0);
  });

  it('logs only Brevo message identifiers for accepted staging deliveries', async () => {
    const previousNodeEnv = process.env.NODE_ENV;
    const previousAppEnv = process.env.APP_ENV;
    const previousInfo = console.info;
    const loggedMessages: string[] = [];
    process.env.NODE_ENV = 'development';
    process.env.APP_ENV = 'staging';
    console.info = (...data: Parameters<typeof console.info>) => {
      loggedMessages.push(data.map(String).join(' '));
    };

    try {
      const provider = new BrevoEmailProvider({
        apiKey: 'synthetic-api-key',
        senderEmail: 'no-reply@example.com',
        senderName: 'Thaai Seyali',
        fetchImpl: async () =>
          Response.json(
            { messageId: '<brevo-message-123@example.com>' },
            { status: 201 }
          ),
      });
      for (const purpose of [
        'EMAIL_CHANGE',
        'PASSWORD_RESET',
        'DEVELOPER_EMAIL_TEST',
      ] as const) {
        await provider.sendOtp('patient@example.com', '123456', purpose);
      }
    } finally {
      console.info = previousInfo;
      if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = previousNodeEnv;
      if (previousAppEnv === undefined) delete process.env.APP_ENV;
      else process.env.APP_ENV = previousAppEnv;
    }

    assert.equal(loggedMessages.length, 3);
    for (const loggedMessage of loggedMessages) {
      assert.match(loggedMessage, /brevo-message-123@example\.com/);
      assert.equal(loggedMessage.includes('patient@example.com'), false);
      assert.equal(loggedMessage.includes('123456'), false);
      assert.equal(loggedMessage.includes('synthetic-api-key'), false);
    }
  });

  it('rejects recipients outside the configured staging allowlist before dispatch', async () => {
    let dispatchCount = 0;
    const provider = new BrevoEmailProvider({
      apiKey: 'synthetic-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      allowedRecipients: ['allowed@example.com'],
      fetchImpl: async () => {
        dispatchCount += 1;
        return new Response(null, { status: 201 });
      },
    });

    await assert.rejects(
      () =>
        provider.sendOtp(
          'not-allowed@example.com',
          'synthetic-otp',
          'PASSWORD_RESET'
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'EMAIL_RECIPIENT_NOT_ALLOWED'
    );
    assert.equal(dispatchCount, 0);
  });

  it('rejects invalid recipient addresses before dispatch', async () => {
    let dispatchCount = 0;
    const provider = new BrevoEmailProvider({
      apiKey: 'synthetic-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async () => {
        dispatchCount += 1;
        return new Response(null, { status: 201 });
      },
    });

    await assert.rejects(
      () => provider.sendOtp('not-an-email', 'synthetic-otp', 'PASSWORD_RESET'),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL'
    );
    assert.equal(dispatchCount, 0);
  });

  it('returns a sanitized error for Brevo delivery failures', async () => {
    const provider = new BrevoEmailProvider({
      apiKey: 'secret-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            code: 'invalid_parameter',
            message:
              'Invalid API key secret-key for patient@example.com, OTP 123456',
          }),
          { status: 500, headers: { 'content-type': 'application/json' } }
        ),
    });

    await assert.rejects(
      () => provider.sendOtp('patient@example.com', '123456', 'PASSWORD_RESET'),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.errorCode, 'EMAIL_PROVIDER_DELIVERY_FAILURE');
        assert.equal(error.message.includes('secret-key'), false);
        assert.equal(error.message.includes('patient@example.com'), false);
        assert.equal(error.message.includes('123456'), false);
        assert.equal(error.statusCode, 500);
        assert.deepEqual(error.details, {
          provider: 'Brevo',
          source: 'email_provider',
          httpStatus: 500,
          providerCode: 'invalid_parameter',
          providerMessage:
            'Invalid API key [redacted] for [redacted email], OTP [redacted]',
        });
        return true;
      }
    );
  });

  it('preserves Brevo Retry-After on transactional email rate limits', async () => {
    const provider = new BrevoEmailProvider({
      apiKey: 'synthetic-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async () =>
        Response.json(
          {
            code: 'rate_limit_exceeded',
            message: 'Authorization: Bearer synthetic-secret-token',
          },
          { status: 429, headers: { 'retry-after': '120' } }
        ),
    });

    await assert.rejects(
      () => provider.sendOtp('patient@example.com', '123456', 'PASSWORD_RESET'),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.errorCode, 'BREVO_RATE_LIMITED');
        assert.equal(error.message.includes('synthetic-secret-token'), false);
        assert.deepEqual(error.details, {
          provider: 'Brevo',
          source: 'email_provider',
          httpStatus: 429,
          providerCode: 'rate_limit_exceeded',
          providerMessage: 'Authorization=[redacted]',
          retryAfterSeconds: 120,
        });
        return true;
      }
    );
  });

  it('identifies Brevo credential and sender rejection without returning provider details', async () => {
    const credentialErrorProvider = new BrevoEmailProvider({
      apiKey: 'secret-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            code: 'invalid_api_key',
            message:
              'The sender is not verified; the secret-key is invalid for patient@example.com (OTP 123456)',
          }),
          { status: 401, headers: { 'content-type': 'application/json' } }
        ),
    });
    const senderErrorProvider = new BrevoEmailProvider({
      apiKey: 'secret-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            code: 'invalid_parameter',
            message: 'The sender address is not verified',
          }),
          { status: 400, headers: { 'content-type': 'application/json' } }
        ),
    });

    await assert.rejects(
      () =>
        credentialErrorProvider.sendOtp(
          'patient@example.com',
          '123456',
          'PASSWORD_RESET'
        ),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.errorCode, 'BREVO_AUTHENTICATION_FAILED');
        assert.equal(error.message.includes('secret-key'), false);
        assert.equal(error.message.includes('patient@example.com'), false);
        assert.equal(error.message.includes('123456'), false);
        assert.equal(error.statusCode, 401);
        assert.deepEqual(error.details, {
          provider: 'Brevo',
          source: 'email_provider',
          httpStatus: 401,
          providerCode: 'invalid_api_key',
          providerMessage:
            'The sender is not verified; the [redacted] is invalid for [redacted email] (OTP [redacted])',
        });
        assert.doesNotMatch(error.message, /SMTP key/i);
        return true;
      }
    );
    await assert.rejects(
      () =>
        senderErrorProvider.sendOtp(
          'patient@example.com',
          '123456',
          'PASSWORD_RESET'
        ),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.errorCode, 'BREVO_SENDER_REJECTED');
        assert.equal(error.statusCode, 400);
        assert.match(error.message, /Brevo rejected the configured sender/);
        assert.deepEqual(error.details, {
          provider: 'Brevo',
          source: 'email_provider',
          httpStatus: 400,
          providerCode: 'invalid_parameter',
          providerMessage: 'The sender address is not verified',
        });
        return true;
      }
    );

    const permissionErrorProvider = new BrevoEmailProvider({
      apiKey: 'secret-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async () =>
        new Response(
          JSON.stringify({
            code: 'permission_denied',
            message: 'The API key is not permitted to send email',
          }),
          { status: 403, headers: { 'content-type': 'application/json' } }
        ),
    });
    await assert.rejects(
      () =>
        permissionErrorProvider.sendOtp(
          'patient@example.com',
          '123456',
          'PASSWORD_RESET'
        ),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.errorCode, 'BREVO_PERMISSION_DENIED');
        assert.equal(error.statusCode, 403);
        assert.deepEqual(error.details, {
          provider: 'Brevo',
          source: 'email_provider',
          httpStatus: 403,
          providerCode: 'permission_denied',
          providerMessage: 'The API key is not permitted to send email',
        });
        return true;
      }
    );
  });

  it('aborts provider requests that exceed the configured timeout', async () => {
    const provider = new BrevoEmailProvider({
      apiKey: 'test-key',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      timeoutMs: 5,
      fetchImpl: async (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener(
            'abort',
            () => reject(new DOMException('Aborted', 'AbortError')),
            { once: true }
          );
        }),
    });

    await assert.rejects(
      () => provider.sendOtp('patient@example.com', '123456', 'EMAIL_CHANGE'),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'EMAIL_PROVIDER_TIMEOUT'
    );
  });

  it('fails safely when sender or API configuration is missing', async () => {
    const provider = new BrevoEmailProvider({
      apiKey: '',
      senderEmail: 'no-reply@example.com',
      senderName: 'Thaai Seyali',
      fetchImpl: async () => {
        throw new Error('Fetch must not be called.');
      },
    });

    await assert.rejects(
      () => provider.sendOtp('patient@example.com', '123456', 'EMAIL_CHANGE'),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'EMAIL_PROVIDER_UNCONFIGURED'
    );

    const invalidSenderProvider = new BrevoEmailProvider({
      apiKey: 'synthetic-key',
      senderEmail: 'not-an-email',
      senderName: 'Thaai Seyali',
      fetchImpl: async () => {
        throw new Error('Fetch must not be called.');
      },
    });
    await assert.rejects(
      () =>
        invalidSenderProvider.sendOtp(
          'patient@example.com',
          '123456',
          'EMAIL_CHANGE'
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'EMAIL_PROVIDER_UNCONFIGURED'
    );
  });
});
