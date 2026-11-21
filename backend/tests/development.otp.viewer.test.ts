import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { describe, it } from 'node:test';
import express, { Router } from 'express';
import { Pool } from 'pg';
import { getDevelopmentOtpViewerConfig } from '../src/config/runtime';
import { AuthService } from '../src/modules/auth/auth.service';
import {
  MockOtpRepository,
  MockPatientProfileRepository,
  MockRefreshTokenRepository,
  MockUserRepository,
} from '../src/modules/auth/mock.auth.repository';
import { PostgresOtpRepository } from '../src/modules/auth/postgres.auth.repository';
import { DevelopmentSmsProvider } from '../src/modules/auth/sms.provider';
import {
  createAuthRouter,
  resetDefaultAuthServiceForTesting,
} from '../src/modules/auth/auth.routes';
import { createDevelopmentOtpViewerRouter } from '../src/modules/auth/development.otp.viewer';

const viewerSecret = 'A'.repeat(43);
const allowedPhone = '+919876543210';

const environmentKeys = [
  'APP_ENV',
  'NODE_ENV',
  'DEV_OTP_VIEWER_ENABLED',
  'DEV_OTP_VIEWER_SECRET',
  'DEV_OTP_VIEWER_ALLOWED_PHONES',
] as const;

async function withEnvironment<T>(
  values: Partial<Record<(typeof environmentKeys)[number], string>>,
  action: () => Promise<T>
): Promise<T> {
  const previous = new Map(
    environmentKeys.map((key) => [key, process.env[key]])
  );
  for (const key of environmentKeys) delete process.env[key];
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

function createAuthService() {
  const userRepo = new MockUserRepository();
  const otpRepo = new MockOtpRepository();
  const smsProvider = new DevelopmentSmsProvider();
  const service = new AuthService(
    userRepo,
    new MockPatientProfileRepository(),
    otpRepo,
    new MockRefreshTokenRepository(userRepo),
    smsProvider,
    {
      jwtAccessSecret: 'test_jwt_access_secret_at_least_32_chars',
      otpSecret: 'test_otp_secret_at_least_32_characters',
    }
  );
  return { service, otpRepo };
}

async function withRouter<T>(
  router: Router,
  action: (baseUrl: string) => Promise<T>,
  mountPath = '/api/v1/auth'
): Promise<T> {
  const app = express();
  app.use(express.json());
  app.use(mountPath, router);
  const server = createServer(app);

  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  assert.ok(address && typeof address !== 'string');

  try {
    return await action(`http://127.0.0.1:${address.port}/api/v1/auth`);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

describe('development mobile OTP viewer', () => {
  it('requires explicit enablement and supports development or staging configuration', () => {
    const development = getDevelopmentOtpViewerConfig({
      APP_ENV: 'development',
      NODE_ENV: 'development',
      DEV_OTP_VIEWER_ENABLED: 'true',
      DEV_OTP_VIEWER_SECRET: viewerSecret,
      DEV_OTP_VIEWER_ALLOWED_PHONES: allowedPhone,
    });
    const staging = getDevelopmentOtpViewerConfig({
      APP_ENV: 'staging',
      NODE_ENV: 'development',
      DEV_OTP_VIEWER_ENABLED: 'true',
      DEV_OTP_VIEWER_SECRET: viewerSecret,
      DEV_OTP_VIEWER_ALLOWED_PHONES: allowedPhone,
    });

    assert.ok(development);
    assert.ok(staging);
    assert.equal(development.allowedPhones.has(allowedPhone), true);
    assert.equal(staging.allowedPhones.has(allowedPhone), true);
    assert.equal(
      getDevelopmentOtpViewerConfig({
        APP_ENV: 'development',
        NODE_ENV: 'development',
        DEV_OTP_VIEWER_ENABLED: 'false',
      }),
      null
    );
  });

  it('refuses production or ambiguous environment enablement', () => {
    const settings = {
      DEV_OTP_VIEWER_ENABLED: 'true',
      DEV_OTP_VIEWER_SECRET: viewerSecret,
      DEV_OTP_VIEWER_ALLOWED_PHONES: allowedPhone,
    };

    assert.throws(
      () =>
        getDevelopmentOtpViewerConfig({
          ...settings,
          APP_ENV: 'development',
          NODE_ENV: 'production',
        }),
      /only in development or staging/
    );
    assert.throws(
      () =>
        getDevelopmentOtpViewerConfig({
          ...settings,
          APP_ENV: 'production',
          NODE_ENV: 'development',
        }),
      /only in development or staging/
    );
    assert.throws(
      () =>
        getDevelopmentOtpViewerConfig({
          ...settings,
          NODE_ENV: 'development',
        }),
      /only in development or staging/
    );
    assert.throws(
      () =>
        getDevelopmentOtpViewerConfig({
          ...settings,
          APP_ENV: 'development',
          NODE_ENV: 'development',
          JWT_ACCESS_SECRET: viewerSecret,
        }),
      /different from authentication secrets/
    );
  });

  it('returns only the current allowlisted OTP in enabled development or staging', async () => {
    for (const environment of [
      { APP_ENV: 'development', NODE_ENV: 'test' },
      { APP_ENV: 'staging', NODE_ENV: 'development' },
    ]) {
      await withEnvironment(environment, async () => {
        const { service } = createAuthService();
        await service.sendOtp(allowedPhone, 'REGISTRATION', '127.0.0.1');
        const expectedOtp = await service.getActiveDevelopmentOtp(
          allowedPhone,
          'REGISTRATION'
        );
        assert.ok(expectedOtp);

        await withEnvironment(
          {
            ...environment,
            DEV_OTP_VIEWER_ENABLED: 'true',
            DEV_OTP_VIEWER_SECRET: viewerSecret,
            DEV_OTP_VIEWER_ALLOWED_PHONES: allowedPhone,
          },
          async () => {
            await withRouter(
              createDevelopmentOtpViewerRouter(service),
              async (baseUrl) => {
                const response = await fetch(`${baseUrl}/dev/otp/view`, {
                  method: 'POST',
                  headers: {
                    Authorization: `Bearer ${viewerSecret}`,
                    'Content-Type': 'application/json',
                  },
                  body: JSON.stringify({
                    phone: allowedPhone,
                    purpose: 'REGISTRATION',
                  }),
                });
                const payload = (await response.json()) as Record<
                  string,
                  unknown
                >;

                assert.equal(response.status, 200);
                assert.deepEqual(Object.keys(payload), ['otp']);
                const otp = payload.otp;
                assert.ok(typeof otp === 'string');
                assert.ok(/^\d{6}$/.test(otp));
                assert.ok(otp === expectedOtp);
                assert.equal(
                  response.headers.get('cache-control')?.includes('no-store'),
                  true
                );
              },
              '/api/v1/auth/dev/otp'
            );
          }
        );
      });
    }
  });

  it('rejects invalid input, incorrect secrets, and numbers outside the allowlist without returning an OTP', async () => {
    await withEnvironment(
      { APP_ENV: 'development', NODE_ENV: 'test' },
      async () => {
        const { service } = createAuthService();
        await service.sendOtp(allowedPhone, 'REGISTRATION', '127.0.0.1');

        await withEnvironment(
          {
            APP_ENV: 'development',
            NODE_ENV: 'test',
            DEV_OTP_VIEWER_ENABLED: 'true',
            DEV_OTP_VIEWER_SECRET: viewerSecret,
            DEV_OTP_VIEWER_ALLOWED_PHONES: allowedPhone,
          },
          async () => {
            await withRouter(
              createDevelopmentOtpViewerRouter(service),
              async (baseUrl) => {
                const request = (body: object, secret = viewerSecret) =>
                  fetch(`${baseUrl}/dev/otp/view`, {
                    method: 'POST',
                    headers: {
                      Authorization: `Bearer ${secret}`,
                      'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(body),
                  });

                const invalidPhone = await request({
                  phone: 'not-a-phone',
                  purpose: 'REGISTRATION',
                });
                const invalidPurpose = await request({
                  phone: allowedPhone,
                  purpose: 'PASSWORD_RESET',
                });
                const incorrectSecret = await request(
                  { phone: allowedPhone, purpose: 'REGISTRATION' },
                  'wrong-viewer-key'
                );
                const otherPhone = await request({
                  phone: '+919876543211',
                  purpose: 'REGISTRATION',
                });

                assert.equal(invalidPhone.status, 400);
                assert.equal(invalidPurpose.status, 400);
                assert.equal(incorrectSecret.status, 404);
                assert.equal(otherPhone.status, 404);
                for (const response of [
                  invalidPhone,
                  invalidPurpose,
                  incorrectSecret,
                  otherPhone,
                ]) {
                  const payload = (await response.json()) as Record<
                    string,
                    unknown
                  >;
                  assert.equal('otp' in payload, false);
                }
              },
              '/api/v1/auth/dev/otp'
            );
          }
        );
      }
    );
  });

  it('does not return expired or consumed challenges', async () => {
    await withEnvironment(
      { APP_ENV: 'development', NODE_ENV: 'test' },
      async () => {
        const { service, otpRepo } = createAuthService();

        await service.sendOtp(allowedPhone, 'REGISTRATION', '127.0.0.1');
        const expiredChallenge = await otpRepo.findLatestActiveChallenge(
          allowedPhone,
          'REGISTRATION'
        );
        assert.ok(expiredChallenge);
        otpRepo.expireChallengeForTesting(expiredChallenge.id);
        assert.equal(
          await service.getActiveDevelopmentOtp(
            allowedPhone,
            'REGISTRATION'
          ),
          null
        );

        const secondPhone = '+919876543211';
        await service.sendOtp(secondPhone, 'REGISTRATION', '127.0.0.1');
        const consumedChallenge = await otpRepo.findLatestActiveChallenge(
          secondPhone,
          'REGISTRATION'
        );
        assert.ok(consumedChallenge);
        assert.equal(await otpRepo.consume(consumedChallenge.id), true);
        assert.equal(
          await service.getActiveDevelopmentOtp(
            secondPhone,
            'REGISTRATION'
          ),
          null
        );

        const thirdPhone = '+919876543212';
        await service.sendOtp(thirdPhone, 'REGISTRATION', '127.0.0.1');
        const exhaustedChallenge = await otpRepo.findLatestActiveChallenge(
          thirdPhone,
          'REGISTRATION'
        );
        assert.ok(exhaustedChallenge);
        for (let attempt = 0; attempt < exhaustedChallenge.maxAttempts; attempt++) {
          await otpRepo.incrementAttempts(exhaustedChallenge.id);
        }
        assert.equal(
          await service.getActiveDevelopmentOtp(
            thirdPhone,
            'REGISTRATION'
          ),
          null
        );
      }
    );
  });

  it('does not mount the OTP viewer endpoint in the auth API', async () => {
    await withEnvironment(
      {
        APP_ENV: 'development',
        NODE_ENV: 'test',
        DEV_OTP_VIEWER_ENABLED: 'true',
        DEV_OTP_VIEWER_SECRET: viewerSecret,
        DEV_OTP_VIEWER_ALLOWED_PHONES: allowedPhone,
      },
      async () => {
        resetDefaultAuthServiceForTesting();
        try {
          await withRouter(createAuthRouter(), async (baseUrl) => {
            const response = await fetch(`${baseUrl}/dev/otp/view`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                phone: allowedPhone,
                purpose: 'REGISTRATION',
              }),
            });
            assert.equal(response.status, 404);
            await response.text();
          });
        } finally {
          resetDefaultAuthServiceForTesting();
        }
      }
    );
  });

  it('queries PostgreSQL for only an unexpired, unconsumed, non-exhausted challenge', async () => {
    let queryText = '';
    let queryParams: unknown[] | undefined;
    const createdAt = new Date();
    const expiresAt = new Date(Date.now() + 60_000);
    const pool = {
      query: async (text: string, params?: unknown[]) => {
        queryText = text;
        queryParams = params;
        return {
          rowCount: 1,
          rows: [
            {
              id: 'challenge-id',
              phone: allowedPhone,
              otp_hash: 'a'.repeat(64),
              purpose: 'REGISTRATION',
              attempts_count: 0,
              max_attempts: 3,
              expires_at: expiresAt,
              consumed_at: null,
              ip_address: '127.0.0.1',
              created_at: createdAt,
            },
          ],
        };
      },
    } as unknown as Pool;

    const challenge = await new PostgresOtpRepository(
      pool
    ).findLatestActiveChallenge(allowedPhone, 'REGISTRATION');

    assert.ok(challenge);
    assert.match(queryText, /consumed_at IS NULL/);
    assert.match(queryText, /expires_at > NOW\(\)/);
    assert.match(queryText, /attempts_count < max_attempts/);
    assert.deepEqual(queryParams, [allowedPhone, 'REGISTRATION']);
  });
});
