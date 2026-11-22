import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Pool } from 'pg';
import {
  getAuthRepositoryMode,
  getConfiguredDatabaseName,
  getDevelopmentEmailAllowedRecipients,
  getLocalDevelopmentDatabaseUrl,
  getStagingDatabaseUrl,
  getStagingDeveloperEmailOtpRateLimits,
  getStagingEmailAllowedRecipients,
  isDeveloperEmailOtpTestEnabled,
  resolveDatabaseUrl,
} from '../src/config/runtime';
import {
  BrevoEmailProvider,
  createEmailProvider,
} from '../src/modules/auth/email.provider';
import {
  createSmsProvider,
  DevelopmentSmsProvider,
  getSmsProviderName,
  ProductionSmsProvider,
} from '../src/modules/auth/sms.provider';
import {
  createPersistentAuthService,
  createPersistentEmailAuthService,
  createPersistentPasswordAuthService,
} from '../src/modules/auth/auth.routes';
import { IEmailProvider } from '../src/modules/auth/email.provider.interface';

const stagingDatabaseUrl =
  'postgresql://test:test@127.0.0.1:5432/ascas_email_otp_test';
const stagingSecrets = {
  JWT_ACCESS_SECRET: 'staging_test_jwt_secret_minimum_32_characters!',
  OTP_SECRET: 'staging_test_otp_secret_minimum_32_characters!',
};

const managedEnvironmentKeys = [
  'APP_ENV',
  'NODE_ENV',
  'DATABASE_URL',
  'STAGING_DATABASE_URL',
  'STAGING_DATABASE_DISPOSABLE',
  'DEV_PERSISTENT_AUTH',
  'DEV_EMAIL_ALLOWED_RECIPIENTS',
  'DEV_EMAIL_ALLOW_ANY_RECIPIENT',
  'DEV_EMAIL_ALLOW_ALL_RECIPIENTS',
  'STAGING_BREVO_ENABLED',
  'STAGING_BREVO_ALLOW_ALL_RECIPIENTS',
  'STAGING_EMAIL_ALLOW_ANY_RECIPIENT',
  'STAGING_EMAIL_ALLOWED_RECIPIENTS',
  'STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED',
  'DEV_EMAIL_OTP_TEST_ENABLED',
  'STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL',
  'STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP',
  'BREVO_API_KEY',
  'BREVO_SENDER_EMAIL',
  'BREVO_SENDER_NAME',
  'JWT_ACCESS_SECRET',
  'OTP_SECRET',
] as const;

async function withEnvironment<T>(
  values: Partial<Record<(typeof managedEnvironmentKeys)[number], string>>,
  action: () => T | Promise<T>
): Promise<T> {
  const previous = new Map(
    managedEnvironmentKeys.map((key) => [key, process.env[key]])
  );
  for (const key of managedEnvironmentKeys) {
    delete process.env[key];
  }
  Object.assign(process.env, values);

  try {
    return await action();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

const validStagingDatabase = {
  APP_ENV: 'staging',
  NODE_ENV: 'development',
  STAGING_DATABASE_URL: stagingDatabaseUrl,
  STAGING_DATABASE_DISPOSABLE: 'true',
  ...stagingSecrets,
};

describe('isolated staging mode', () => {
  it('uses persistent local auth only with the loopback test database', () => {
    const localDatabaseUrl =
      'postgresql://test:test@127.0.0.1:5432/thaai_seyali_test';
    const localEnvironment = {
      APP_ENV: 'development',
      NODE_ENV: 'development',
      DEV_PERSISTENT_AUTH: 'true',
      DATABASE_URL: localDatabaseUrl,
    };

    assert.equal(
      getLocalDevelopmentDatabaseUrl(localEnvironment),
      localDatabaseUrl
    );
    assert.equal(resolveDatabaseUrl(localEnvironment), localDatabaseUrl);
    assert.equal(
      getConfiguredDatabaseName(localEnvironment),
      'thaai_seyali_test'
    );
    assert.equal(
      getAuthRepositoryMode(localEnvironment),
      'development-persistent'
    );
    assert.equal(
      getSmsProviderName(localEnvironment),
      'DevelopmentSmsProvider'
    );
    assert.equal(
      getSmsProviderName({
        APP_ENV: 'staging',
        NODE_ENV: 'development',
      }),
      'DevelopmentSmsProvider'
    );
    assert.equal(
      getSmsProviderName({
        APP_ENV: 'production',
        NODE_ENV: 'production',
      }),
      'ProductionSmsProvider'
    );
    assert.throws(
      () =>
        getAuthRepositoryMode({
          ...localEnvironment,
          DATABASE_URL:
            'postgresql://test:test@db.example.test/thaai_seyali_test',
        }),
      /must target loopback PostgreSQL database thaai_seyali_test/
    );
    assert.throws(
      () =>
        getAuthRepositoryMode({
          ...localEnvironment,
          DATABASE_URL:
            'postgresql://test:test@127.0.0.1:5432/thaai_seyali_staging',
        }),
      /must target loopback PostgreSQL database thaai_seyali_test/
    );
  });

  it('uses safe defaults and validates configurable developer email OTP limits', () => {
    assert.deepEqual(
      getStagingDeveloperEmailOtpRateLimits({
        APP_ENV: 'staging',
        NODE_ENV: 'development',
      }),
      {
        maxRequestsPerHourPerEmail: 5,
        maxRequestsPerHourPerIp: 15,
      }
    );
    assert.deepEqual(
      getStagingDeveloperEmailOtpRateLimits({
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL: '8',
        STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP: '24',
      }),
      {
        maxRequestsPerHourPerEmail: 8,
        maxRequestsPerHourPerIp: 24,
      }
    );
    assert.throws(
      () =>
        getStagingDeveloperEmailOtpRateLimits({
          APP_ENV: 'staging',
          NODE_ENV: 'development',
          STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL: '0',
        }),
      /must be a positive safe integer/
    );
    assert.throws(
      () =>
        getStagingDeveloperEmailOtpRateLimits({
          APP_ENV: 'production',
          NODE_ENV: 'production',
        }),
      /APP_ENV=staging is required/
    );
  });

  it('enables developer email OTP testing only with an explicit staging or isolated development flag', async () => {
    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED: 'true',
      },
      () => {
        assert.equal(isDeveloperEmailOtpTestEnabled(process.env), true);
      }
    );

    assert.equal(
      isDeveloperEmailOtpTestEnabled({
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED: 'false',
      }),
      false
    );
    assert.equal(
      isDeveloperEmailOtpTestEnabled({
        APP_ENV: 'production',
        NODE_ENV: 'production',
        STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED: 'true',
      }),
      false
    );
    assert.equal(
      isDeveloperEmailOtpTestEnabled({
        APP_ENV: 'development',
        NODE_ENV: 'development',
        DEV_EMAIL_OTP_TEST_ENABLED: 'true',
        DEV_PERSISTENT_AUTH: 'true',
        DATABASE_URL:
          'postgresql://test:test@127.0.0.1:5432/thaai_seyali_test',
      }),
      true
    );
    assert.equal(
      isDeveloperEmailOtpTestEnabled({
        APP_ENV: 'development',
        NODE_ENV: 'development',
        DEV_EMAIL_OTP_TEST_ENABLED: 'true',
        DEV_PERSISTENT_AUTH: 'false',
      }),
      false
    );
    assert.equal(
      isDeveloperEmailOtpTestEnabled({
        APP_ENV: 'development',
        NODE_ENV: 'production',
        DEV_EMAIL_OTP_TEST_ENABLED: 'true',
        DEV_PERSISTENT_AUTH: 'true',
        DATABASE_URL:
          'postgresql://test:test@127.0.0.1:5432/thaai_seyali_test',
      }),
      false
    );
  });

  it('uses only an explicitly marked loopback staging database', () => {
    assert.equal(
      getStagingDatabaseUrl(validStagingDatabase),
      stagingDatabaseUrl
    );
    assert.equal(resolveDatabaseUrl(validStagingDatabase), stagingDatabaseUrl);
    assert.equal(getAuthRepositoryMode(validStagingDatabase), 'staging');

    assert.throws(
      () =>
        getAuthRepositoryMode({
          APP_ENV: 'staging',
          NODE_ENV: 'development',
          STAGING_DATABASE_DISPOSABLE: 'true',
        }),
      /STAGING_DATABASE_URL is required/
    );
    assert.throws(
      () =>
        getStagingDatabaseUrl({
          APP_ENV: 'staging',
          NODE_ENV: 'development',
          STAGING_DATABASE_URL: stagingDatabaseUrl,
        }),
      /STAGING_DATABASE_DISPOSABLE must be explicitly set/
    );
    assert.throws(
      () =>
        getStagingDatabaseUrl({
          ...validStagingDatabase,
          DATABASE_URL: 'postgresql://other:other@db.example.test/app',
        }),
      /DATABASE_URL must be unset in staging/
    );
    assert.throws(
      () =>
        getStagingDatabaseUrl({
          ...validStagingDatabase,
          STAGING_DATABASE_URL:
            'postgresql://test:test@db.example.test/ascas_email_otp_test',
        }),
      /loopback PostgreSQL database/
    );
    assert.equal(
      getAuthRepositoryMode({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://production.example.test/app',
      }),
      'production'
    );
    assert.throws(
      () =>
        getAuthRepositoryMode({
          ...validStagingDatabase,
          NODE_ENV: 'production',
        }),
      /cannot be combined with NODE_ENV=production/
    );
  });

  it('constructs persistent staging services only with valid disposable configuration', async () => {
    const mockPool = {
      query: async () => ({ rowCount: 0, rows: [] }),
      connect: async () => ({
        query: async () => ({ rowCount: 0, rows: [] }),
        release: () => undefined,
      }),
    } as unknown as Pool;
    const mockEmailProvider: IEmailProvider = {
      sendOtp: async () => undefined,
    };

    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_DATABASE_DISPOSABLE: 'true',
        ...stagingSecrets,
      },
      () => {
        assert.throws(
          () => createPersistentAuthService(mockPool),
          /STAGING_DATABASE_URL is required/
        );
      }
    );

    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_DATABASE_URL: stagingDatabaseUrl,
        STAGING_DATABASE_DISPOSABLE: 'true',
      },
      () => {
        assert.throws(
          () => createPersistentAuthService(mockPool),
          /JWT_ACCESS_SECRET must be at least 32 characters/
        );
        assert.throws(
          () =>
            createPersistentEmailAuthService(mockPool, mockEmailProvider),
          /OTP_SECRET must be at least 32 characters/
        );
      }
    );

    await withEnvironment(
      {
        ...validStagingDatabase,
        STAGING_DATABASE_DISPOSABLE: 'true',
      },
      () => {
        const authService = createPersistentAuthService(
          mockPool,
          new DevelopmentSmsProvider()
        );
        assert.ok(authService);
        assert.ok(
          createPersistentEmailAuthService(mockPool, mockEmailProvider)
        );
        assert.ok(
          createPersistentPasswordAuthService(mockPool, authService)
        );
      }
    );
  });

  it('selects Brevo in staging only when explicitly enabled and fully configured', async () => {
    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
        BREVO_API_KEY: 'synthetic-test-api-key',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
      },
      () => {
        assert.throws(
          () => createEmailProvider(),
          /STAGING_BREVO_ENABLED must be explicitly set/
        );
      }
    );

    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_BREVO_ENABLED: 'true',
        STAGING_BREVO_ALLOW_ALL_RECIPIENTS: 'false',
        STAGING_EMAIL_ALLOWED_RECIPIENTS:
          'QA.User@example.test, second@example.test',
        BREVO_API_KEY: 'synthetic-test-api-key',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
      },
      () => {
        assert.ok(createEmailProvider() instanceof BrevoEmailProvider);
        assert.deepEqual(
          getStagingEmailAllowedRecipients(process.env),
          ['qa.user@example.test', 'second@example.test']
        );
      }
    );

    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_BREVO_ENABLED: 'true',
        STAGING_BREVO_ALLOW_ALL_RECIPIENTS: 'false',
        STAGING_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
      },
      () => {
        assert.throws(
          () => createEmailProvider(),
          /BREVO_API_KEY is required/
        );
      }
    );
  });

  it('uses allowlisted Brevo delivery for explicitly enabled local email tests', async () => {
    const developmentEmailConfig = {
      APP_ENV: 'development',
      NODE_ENV: 'development',
      DEV_PERSISTENT_AUTH: 'true',
      DEV_EMAIL_OTP_TEST_ENABLED: 'true',
      DATABASE_URL:
        'postgresql://test:test@127.0.0.1:5432/thaai_seyali_test',
      DEV_EMAIL_ALLOWED_RECIPIENTS: 'QA.User@example.test, second@example.test',
      BREVO_API_KEY: 'synthetic-test-api-key',
      BREVO_SENDER_EMAIL: 'sender@example.test',
      BREVO_SENDER_NAME: 'Test Sender',
    };

    await withEnvironment(developmentEmailConfig, () => {
      assert.ok(createEmailProvider() instanceof BrevoEmailProvider);
      assert.deepEqual(getDevelopmentEmailAllowedRecipients(process.env), [
        'qa.user@example.test',
        'second@example.test',
      ]);
    });

    const previousFetch = globalThis.fetch;
    await withEnvironment(
      {
        ...developmentEmailConfig,
        DEV_EMAIL_ALLOWED_RECIPIENTS: '',
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
      },
      async () => {
        let payload: { to: Array<{ email: string }> } | undefined;
        let dispatchCount = 0;
        globalThis.fetch = async (_input, init) => {
          dispatchCount += 1;
          payload = JSON.parse(String(init?.body)) as {
            to: Array<{ email: string }>;
          };
          return new Response(null, { status: 201 });
        };
        try {
          assert.deepEqual(getDevelopmentEmailAllowedRecipients(process.env), []);
          await createEmailProvider().sendOtp(
            '  Any.Valid@Example.test ',
            'synthetic-email-otp',
            'DEVELOPER_EMAIL_TEST'
          );
          assert.deepEqual(payload?.to, [{ email: 'any.valid@example.test' }]);
          await assert.rejects(
            () =>
              createEmailProvider().sendOtp(
                'not-an-email',
                'synthetic-email-otp',
                'DEVELOPER_EMAIL_TEST'
              ),
            /valid recipient email address/
          );
          assert.equal(dispatchCount, 1);
        } finally {
          globalThis.fetch = previousFetch;
        }
      }
    );

    await withEnvironment(
      {
        ...developmentEmailConfig,
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'yes',
      },
      () =>
        assert.throws(
          () => getDevelopmentEmailAllowedRecipients(process.env),
          /DEV_EMAIL_ALLOW_ANY_RECIPIENT must be true or false/
        )
    );

    await withEnvironment(
      {
        ...developmentEmailConfig,
        DEV_EMAIL_ALLOWED_RECIPIENTS: '',
        DEV_EMAIL_ALLOW_ALL_RECIPIENTS: 'true',
      },
      () =>
        assert.throws(
          () => createEmailProvider(),
          /DEV_EMAIL_ALLOWED_RECIPIENTS must contain/
        )
    );

    await withEnvironment(
      {
        ...developmentEmailConfig,
        DEV_EMAIL_ALLOWED_RECIPIENTS: '',
      },
      () => {
        assert.throws(
          () => createEmailProvider(),
          /DEV_EMAIL_ALLOWED_RECIPIENTS must contain/
        );
      }
    );

    await withEnvironment(
      {
        ...developmentEmailConfig,
        DEV_EMAIL_ALLOWED_RECIPIENTS: '',
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'false',
      },
      () =>
        assert.throws(
          () => createEmailProvider(),
          /DEV_EMAIL_ALLOWED_RECIPIENTS must contain/
        )
    );

    await withEnvironment(
      {
        APP_ENV: 'development',
        NODE_ENV: 'production',
        DEV_EMAIL_OTP_TEST_ENABLED: 'true',
        DEV_PERSISTENT_AUTH: 'true',
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
      },
      () =>
        assert.throws(
          () => getDevelopmentEmailAllowedRecipients(process.env),
          /Development Brevo delivery requires the developer email OTP test feature/
        )
    );
  });

  it('allows arbitrary staging recipients only when explicitly enabled', async () => {
    const previousFetch = globalThis.fetch;
    try {
      await withEnvironment(
        {
          APP_ENV: 'staging',
          NODE_ENV: 'development',
          STAGING_BREVO_ENABLED: 'true',
          STAGING_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
          STAGING_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
          BREVO_API_KEY: 'synthetic-test-api-key',
          BREVO_SENDER_EMAIL: 'sender@example.test',
          BREVO_SENDER_NAME: 'Test Sender',
        },
        async () => {
          let payload: { to: Array<{ email: string }> } | undefined;
          globalThis.fetch = async (_input, init) => {
            payload = JSON.parse(String(init?.body)) as {
              to: Array<{ email: string }>;
            };
            return new Response(null, { status: 201 });
          };
          assert.deepEqual(getStagingEmailAllowedRecipients(process.env), []);
          assert.ok(createEmailProvider() instanceof BrevoEmailProvider);
          await createEmailProvider().sendOtp(
            '  Any.Valid@Example.test ',
            'synthetic-email-otp',
            'DEVELOPER_EMAIL_TEST'
          );
          assert.deepEqual(payload?.to, [{ email: 'any.valid@example.test' }]);
        }
      );
    } finally {
      globalThis.fetch = previousFetch;
    }

    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_BREVO_ENABLED: 'true',
        STAGING_EMAIL_ALLOW_ANY_RECIPIENT: 'false',
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
        STAGING_BREVO_ALLOW_ALL_RECIPIENTS: 'true',
        BREVO_API_KEY: 'synthetic-test-api-key',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
        STAGING_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
      },
      () => {
        assert.deepEqual(getStagingEmailAllowedRecipients(process.env), [
          'qa@example.test',
        ]);
      }
    );

    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_BREVO_ENABLED: 'true',
        STAGING_EMAIL_ALLOW_ANY_RECIPIENT: 'yes',
        BREVO_API_KEY: 'synthetic-test-api-key',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
        STAGING_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
      },
      () =>
        assert.throws(
          () => createEmailProvider(),
          /STAGING_EMAIL_ALLOW_ANY_RECIPIENT must be true or false/
        )
    );
  });

  it('isolates the staging any-recipient setting from development and production', async () => {
    await withEnvironment(
      {
        APP_ENV: 'development',
        NODE_ENV: 'development',
        DEV_PERSISTENT_AUTH: 'true',
        DEV_EMAIL_OTP_TEST_ENABLED: 'true',
        STAGING_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'false',
        DEV_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
        DEV_EMAIL_ALLOW_ALL_RECIPIENTS: 'true',
        DATABASE_URL:
          'postgresql://test:test@127.0.0.1:5432/thaai_seyali_test',
        BREVO_API_KEY: 'synthetic-test-api-key',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
      },
      () => {
        assert.deepEqual(getDevelopmentEmailAllowedRecipients(process.env), [
          'qa@example.test',
        ]);
      }
    );

    await withEnvironment(
      {
        APP_ENV: 'production',
        NODE_ENV: 'production',
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
        STAGING_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
        STAGING_BREVO_ALLOW_ALL_RECIPIENTS: 'true',
        STAGING_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
      },
      () => {
        assert.throws(
          () => getStagingEmailAllowedRecipients(process.env),
          /APP_ENV=staging is required/
        );
        assert.throws(
          () => getDevelopmentEmailAllowedRecipients(process.env),
          /Development Brevo delivery requires the developer email OTP test feature/
        );
        assert.ok(createEmailProvider() instanceof BrevoEmailProvider);
      }
    );
  });

  it('keeps the recipient allowlist mandatory and rejects wildcard recipients', async () => {
    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_BREVO_ENABLED: 'true',
        BREVO_API_KEY: 'synthetic-test-api-key',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
        STAGING_EMAIL_ALLOWED_RECIPIENTS: '*',
      },
      () =>
        assert.throws(
          () => createEmailProvider(),
          /STAGING_EMAIL_ALLOWED_RECIPIENTS must contain/
        )
    );
  });

  it('does not let the development allow-all option bypass staging restrictions', async () => {
    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
        STAGING_BREVO_ENABLED: 'true',
        STAGING_EMAIL_ALLOWED_RECIPIENTS: 'qa@example.test',
        DEV_EMAIL_ALLOW_ANY_RECIPIENT: 'true',
        BREVO_API_KEY: 'synthetic-test-api-key',
        BREVO_SENDER_EMAIL: 'sender@example.test',
        BREVO_SENDER_NAME: 'Test Sender',
      },
      async () => {
        const provider = createEmailProvider();
        await assert.rejects(
          () =>
            provider.sendOtp(
              'other@example.test',
              'synthetic-email-otp',
              'PASSWORD_RESET'
            ),
          /configured recipients/
        );
      }
    );
  });

  it('restricts staging delivery to allowlisted recipients without logging secrets or OTPs', async () => {
    let dispatchCount = 0;
    const logLines: string[] = [];
    const originalConsoleLog = console.log;
    const originalConsoleError = console.error;
    const provider = new BrevoEmailProvider({
      apiKey: 'synthetic-staging-api-key',
      senderEmail: 'sender@example.test',
      senderName: 'Test Sender',
      allowedRecipients: ['qa@example.test'],
      fetchImpl: async () => {
        dispatchCount += 1;
        return new Response(null, { status: 201 });
      },
    });

    console.log = (...args: unknown[]) => logLines.push(args.join(' '));
    console.error = (...args: unknown[]) => logLines.push(args.join(' '));
    try {
      await assert.rejects(
        () =>
          provider.sendOtp(
            'other@example.test',
            'synthetic-email-otp',
            'PASSWORD_RESET'
          ),
        (error: unknown) =>
          error instanceof Error &&
          error.message.includes('configured recipients')
      );
      await provider.sendOtp(
        'QA@example.test',
        'synthetic-email-otp',
        'PASSWORD_RESET'
      );
    } finally {
      console.log = originalConsoleLog;
      console.error = originalConsoleError;
    }

    assert.equal(dispatchCount, 1);
    assert.equal(logLines.join(' ').includes('synthetic-staging-api-key'), false);
    assert.equal(logLines.join(' ').includes('synthetic-email-otp'), false);
  });

  it('always uses mock SMS in staging and preserves production provider selection', async () => {
    await withEnvironment(
      {
        APP_ENV: 'staging',
        NODE_ENV: 'development',
      },
      async () => {
        const provider = createSmsProvider();
        assert.ok(provider instanceof DevelopmentSmsProvider);
        await provider.sendOtp('+10000000000', 'synthetic-otp', 'LOGIN');
        assert.equal(provider.sentMessages.length, 1);
      }
    );

    await withEnvironment(
      {
        NODE_ENV: 'production',
      },
      () => {
        assert.ok(createSmsProvider() instanceof ProductionSmsProvider);
        assert.ok(createEmailProvider() instanceof BrevoEmailProvider);
      }
    );

    await withEnvironment(
      {
        NODE_ENV: 'staging',
      },
      () => {
        assert.throws(() => createSmsProvider(), /APP_ENV=staging/);
        assert.throws(() => createEmailProvider(), /APP_ENV=staging/);
      }
    );
  });
});
