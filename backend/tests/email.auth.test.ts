import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'crypto';
import express from 'express';
import http from 'http';
import { AuthService } from '../src/modules/auth/auth.service';
import { EmailAuthService } from '../src/modules/auth/email.auth.service';
import {
  MockEmailOtpRepository,
  MockOtpRepository,
  MockPasswordLoginRateLimitRepository,
  MockPasswordResetGrantRepository,
  MockPatientProfileRepository,
  MockRefreshTokenRepository,
  MockUserRepository,
} from '../src/modules/auth/mock.auth.repository';
import { createAuthRouter } from '../src/modules/auth/auth.routes';
import { DevelopmentSmsProvider } from '../src/modules/auth/sms.provider';
import { IEmailProvider } from '../src/modules/auth/email.provider.interface';
import { errorHandler } from '../src/middleware/errorHandler';
import { AppError, ConflictError } from '../src/utils/errors';
import { PasswordAuthService } from '../src/modules/auth/password.auth.service';
import { BcryptPasswordHasher } from '../src/modules/auth/password.hasher';

const OTP_SECRET = 'email_auth_test_otp_secret_minimum_32_characters';
const JWT_SECRET = 'email_auth_test_jwt_secret_minimum_32_characters';
let nextTestPhone = 1;

function createHarness(emailProviderOverride?: IEmailProvider) {
  const userRepo = new MockUserRepository();
  const emailOtpRepo = new MockEmailOtpRepository();
  const refreshTokenRepo = new MockRefreshTokenRepository(userRepo);
  const passwordResetGrantRepo = new MockPasswordResetGrantRepository(
    userRepo,
    refreshTokenRepo
  );
  const sentMessages: Array<{
    email: string;
    otp: string;
    purpose:
      | 'ACCOUNT_ACTIVATION'
      | 'PASSWORD_RESET'
      | 'EMAIL_CHANGE'
      | 'DEVELOPER_EMAIL_TEST';
  }> = [];
  const emailProvider: IEmailProvider =
    emailProviderOverride ??
    {
      sendOtp: async (email, otp, purpose) => {
        sentMessages.push({ email, otp, purpose });
      },
    };
  const emailAuthService = new EmailAuthService(
    userRepo,
    emailOtpRepo,
    passwordResetGrantRepo,
    emailProvider,
    { otpSecret: OTP_SECRET }
  );

  return {
    userRepo,
    emailOtpRepo,
    passwordResetGrantRepo,
    sentMessages,
    emailAuthService,
    emailProvider,
  };
}

async function withStagingEmailTestEnabled<T>(
  action: () => Promise<T>
): Promise<T> {
  const previousAppEnv = process.env.APP_ENV;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousEnabled =
    process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED;
  const previousEmailLimit =
    process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL;
  const previousIpLimit =
    process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP;
  const previousOtpViewer = process.env.DEV_OTP_VIEWER_ENABLED;
  process.env.APP_ENV = 'staging';
  process.env.NODE_ENV = 'development';
  process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED = 'true';
  delete process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL;
  delete process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP;
  process.env.DEV_OTP_VIEWER_ENABLED = 'false';
  try {
    return await action();
  } finally {
    if (previousAppEnv === undefined) delete process.env.APP_ENV;
    else process.env.APP_ENV = previousAppEnv;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousEnabled === undefined) {
      delete process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED;
    } else {
      process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED =
        previousEnabled;
    }
    if (previousEmailLimit === undefined) {
      delete process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL;
    } else {
      process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL =
        previousEmailLimit;
    }
    if (previousIpLimit === undefined) {
      delete process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP;
    } else {
      process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP =
        previousIpLimit;
    }
    if (previousOtpViewer === undefined) {
      delete process.env.DEV_OTP_VIEWER_ENABLED;
    } else {
      process.env.DEV_OTP_VIEWER_ENABLED = previousOtpViewer;
    }
  }
}

async function createUserWithEmail(
  userRepo: MockUserRepository,
  email: string,
  verified: boolean,
  password?: string
) {
  const suffix = (nextTestPhone++).toString().padStart(6, '0');
  const user = await userRepo.create({ phone: `+919876${suffix}` });
  await userRepo.updateEmail(
    user.id,
    email,
    verified ? new Date() : null,
    null
  );
  if (password) {
    userRepo.setEmailPasswordEligibilityForTesting(
      user.id,
      'NEW_PATIENT_ELIGIBLE'
    );
    await userRepo.setPasswordHash(user.id, password);
  }
  return user;
}

async function createEligibleNewPatient(userRepo: MockUserRepository) {
  const suffix = (nextTestPhone++).toString().padStart(6, '0');
  const user = await userRepo.create({ phone: `+919876${suffix}` });
  userRepo.setEmailPasswordEligibilityForTesting(
    user.id,
    'NEW_PATIENT_ELIGIBLE'
  );
  return user;
}

describe('EmailAuthService', () => {
  it('generates a six-digit OTP and stores only a purpose- and user-bound hash', async () => {
    const harness = createHarness();
    const user = await createEligibleNewPatient(harness.userRepo);
    const result = await harness.emailAuthService.sendActivationOtp(
      'patient@example.com',
      user.id
    );
    const message = harness.sentMessages[0];
    const challenge = await harness.emailOtpRepo.findActiveChallenge(
      result.challengeId,
      'patient@example.com',
      'ACCOUNT_ACTIVATION',
      user.id
    );

    assert.match(message.otp, /^\d{6}$/);
    assert.equal(challenge?.otpHash.length, 64);
    assert.notEqual(challenge?.otpHash, message.otp);
    assert.equal(
      challenge?.otpHash,
      harness.emailAuthService.hashOtp(
        'patient@example.com',
        'ACCOUNT_ACTIVATION',
        user.id,
        message.otp
      )
    );
    assert.equal(challenge?.maxAttempts, 5);
    assert.ok(
      challenge &&
        challenge.expiresAt.getTime() - Date.now() <= 5 * 60 * 1000 &&
        challenge.expiresAt.getTime() - Date.now() > 4 * 60 * 1000
    );
  });

  it('activates an email only after a correct OTP and consumes that OTP once', async () => {
    const harness = createHarness();
    const user = await createEligibleNewPatient(harness.userRepo);
    const request = await harness.emailAuthService.sendActivationOtp(
      'patient@example.com',
      user.id
    );
    const otp = harness.sentMessages[0].otp;

    const result = await harness.emailAuthService.verifyActivationOtp(
      request.challengeId,
      'patient@example.com',
      otp,
      user.id
    );
    assert.deepEqual(result, {
      purpose: 'ACCOUNT_ACTIVATION',
      verified: true,
    });
    assert.ok((await harness.userRepo.findById(user.id))?.emailVerifiedAt);

    await assert.rejects(
      () =>
        harness.emailAuthService.verifyActivationOtp(
          request.challengeId,
          'patient@example.com',
          otp,
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
    );
  });

  it('rejects incorrect OTPs and locks the challenge after five attempts', async () => {
    const harness = createHarness();
    const user = await createEligibleNewPatient(harness.userRepo);
    const request = await harness.emailAuthService.sendActivationOtp(
      'patient@example.com',
      user.id
    );

    for (let attempt = 0; attempt < 5; attempt += 1) {
      await assert.rejects(
        () =>
          harness.emailAuthService.verifyActivationOtp(
            request.challengeId,
            'patient@example.com',
            '000001',
            user.id
          ),
        (error: unknown) =>
          error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
      );
    }

    assert.equal(
      await harness.emailOtpRepo.findActiveChallenge(
        request.challengeId,
        'patient@example.com',
        'ACCOUNT_ACTIVATION',
        user.id
      ),
      null
    );
    await assert.rejects(
      () =>
        harness.emailAuthService.verifyActivationOtp(
          request.challengeId,
          'patient@example.com',
          harness.sentMessages[0].otp,
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
    );
  });

  it('rejects expired email OTP challenges', async () => {
    const harness = createHarness();
    const user = await createEligibleNewPatient(harness.userRepo);
    const request = await harness.emailAuthService.sendActivationOtp(
      'patient@example.com',
      user.id
    );
    harness.emailOtpRepo.expireChallengeForTesting(request.challengeId);

    await assert.rejects(
      () =>
        harness.emailAuthService.verifyActivationOtp(
          request.challengeId,
          'patient@example.com',
          harness.sentMessages[0].otp,
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
    );
    assert.equal((await harness.userRepo.findById(user.id))?.emailVerifiedAt, null);
  });

  it('changes an unverified existing email only after the authenticated user verifies the new address', async () => {
    const harness = createHarness();
    const firstUser = await createUserWithEmail(
      harness.userRepo,
      'first@example.com',
      false
    );
    const secondUser = await createUserWithEmail(
      harness.userRepo,
      'second@example.com',
      true
    );
    const request = await harness.emailAuthService.sendOtp(
      ' New@Example.COM ',
      'EMAIL_CHANGE',
      firstUser.id
    );
    assert.equal(harness.sentMessages[0].email, 'new@example.com');
    assert.equal(harness.sentMessages[0].purpose, 'EMAIL_CHANGE');
    const otp = harness.sentMessages[0].otp;
    assert.equal(
      (await harness.userRepo.findById(firstUser.id))?.email,
      'first@example.com'
    );
    assert.equal(
      (await harness.userRepo.findById(firstUser.id))?.emailVerifiedAt,
      null
    );

    await assert.rejects(
      () =>
        harness.emailAuthService.verifyOtp(
          request.challengeId,
          'new@example.com',
          'EMAIL_CHANGE',
          otp,
          secondUser.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
    );
    assert.equal(
      (await harness.userRepo.findById(firstUser.id))?.email,
      'first@example.com'
    );
    assert.equal(
      (await harness.userRepo.findById(firstUser.id))?.emailVerifiedAt,
      null
    );

    const result = await harness.emailAuthService.verifyOtp(
      request.challengeId,
      'new@example.com',
      'EMAIL_CHANGE',
      otp,
      firstUser.id
    );
    assert.deepEqual(result, {
      purpose: 'EMAIL_CHANGE',
      verified: true,
      email: 'new@example.com',
    });
    assert.equal(
      (await harness.userRepo.findByEmail('new@example.com'))?.id,
      firstUser.id
    );
    assert.ok((await harness.userRepo.findById(firstUser.id))?.emailVerifiedAt);

    await assert.rejects(
      () =>
        harness.emailAuthService.verifyOtp(
          request.challengeId,
          'new@example.com',
          'EMAIL_CHANGE',
          otp,
          firstUser.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
    );
  });

  it('leaves an unverified existing email unchanged after invalid or expired email-change OTPs', async () => {
    const harness = createHarness();
    const user = await createUserWithEmail(
      harness.userRepo,
      'old@example.com',
      false
    );
    const request = await harness.emailAuthService.sendOtp(
      'new@example.com',
      'EMAIL_CHANGE',
      user.id
    );

    await assert.rejects(
      () =>
        harness.emailAuthService.verifyOtp(
          request.challengeId,
          'new@example.com',
          'EMAIL_CHANGE',
          '000000',
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
    );
    assert.equal(
      (await harness.userRepo.findById(user.id))?.email,
      'old@example.com'
    );
    assert.equal(
      (await harness.userRepo.findById(user.id))?.emailVerifiedAt,
      null
    );

    harness.emailOtpRepo.expireChallengeForTesting(request.challengeId);
    await assert.rejects(
      () =>
        harness.emailAuthService.verifyOtp(
          request.challengeId,
          'new@example.com',
          'EMAIL_CHANGE',
          harness.sentMessages[0].otp,
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'INVALID_EMAIL_OTP'
    );
    assert.equal(
      (await harness.userRepo.findById(user.id))?.email,
      'old@example.com'
    );
    assert.equal(
      (await harness.userRepo.findById(user.id))?.emailVerifiedAt,
      null
    );
  });

  it('rejects normalized duplicate addresses for email changes and preserves the old email', async () => {
    const harness = createHarness();
    await createUserWithEmail(
      harness.userRepo,
      'taken@example.com',
      true
    );
    const user = await createUserWithEmail(
      harness.userRepo,
      'old@example.com',
      false
    );

    await assert.rejects(
      () =>
        harness.emailAuthService.sendOtp(
          ' TAkEN@example.com ',
          'EMAIL_CHANGE',
          user.id
        ),
      ConflictError
    );
    assert.equal((await harness.userRepo.findById(user.id))?.email, 'old@example.com');
    assert.equal(harness.sentMessages.length, 0);

    const request = await harness.emailAuthService.sendOtp(
      'race@example.com',
      'EMAIL_CHANGE',
      user.id
    );
    const raceOwner = await createUserWithEmail(
      harness.userRepo,
      'RACE@example.com',
      true
    );
    await assert.rejects(
      () =>
        harness.emailAuthService.verifyOtp(
          request.challengeId,
          'race@example.com',
          'EMAIL_CHANGE',
          harness.sentMessages[0].otp,
          user.id
        ),
      ConflictError
    );
    assert.equal(
      (await harness.userRepo.findById(user.id))?.email,
      'old@example.com'
    );
    assert.equal(
      (await harness.userRepo.findById(user.id))?.emailVerifiedAt,
      null
    );
    assert.equal(
      (await harness.userRepo.findByEmail('race@example.com'))?.id,
      raceOwner.id
    );
  });

  it('rejects purpose substitution', async () => {
    const harness = createHarness();
    const user = await createEligibleNewPatient(harness.userRepo);
    const request = await harness.emailAuthService.sendActivationOtp(
      'patient@example.com',
      user.id
    );
    const otp = harness.sentMessages[0].otp;

    await assert.rejects(
      () =>
        harness.emailAuthService.verifyOtp(
          request.challengeId,
          'patient@example.com',
          'EMAIL_CHANGE',
          otp,
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'FORBIDDEN'
    );
    assert.ok(
      await harness.emailAuthService.verifyActivationOtp(
        request.challengeId,
        'patient@example.com',
        otp,
        user.id
      )
    );
  });

  it('does not expose initial activation through the generic email OTP service', async () => {
    const harness = createHarness();
    const user = await createEligibleNewPatient(harness.userRepo);

    await assert.rejects(
      () =>
        harness.emailAuthService.sendOtp(
          'patient@example.com',
          'ACCOUNT_ACTIVATION',
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'VALIDATION_ERROR'
    );
    assert.equal(harness.sentMessages.length, 0);
  });

  it('sends and verifies an account-independent developer OTP without auth side effects', async () => {
    await withStagingEmailTestEnabled(async () => {
      const harness = createHarness();
      const result =
        await harness.emailAuthService.sendDeveloperEmailTestOtp(
          '  Test.Recipient@Example.COM  ',
          '127.0.0.1'
        );
      const message = harness.sentMessages[0];
      const challenge = await harness.emailOtpRepo.findActiveChallenge(
        result.challengeId,
        'test.recipient@example.com',
        'DEVELOPER_EMAIL_TEST',
        null
      );

      assert.equal(message.email, 'test.recipient@example.com');
      assert.equal(message.purpose, 'DEVELOPER_EMAIL_TEST');
      assert.match(message.otp, /^\d{6}$/);
      assert.equal(challenge?.userId, null);
      assert.equal(challenge?.otpHash.length, 64);
      assert.notEqual(challenge?.otpHash, message.otp);
      assert.equal(challenge?.maxAttempts, 5);
      assert.ok(
        challenge &&
          challenge.expiresAt.getTime() - Date.now() <= 5 * 60 * 1000 &&
          challenge.expiresAt.getTime() - Date.now() > 4 * 60 * 1000
      );

      await assert.rejects(
        () =>
          harness.emailAuthService.verifyDeveloperEmailTestOtp(
            result.challengeId,
            'other.recipient@example.com',
            message.otp
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'INVALID_EMAIL_OTP'
      );
      const verified =
        await harness.emailAuthService.verifyDeveloperEmailTestOtp(
          result.challengeId,
          'TEST.RECIPIENT@example.com',
          message.otp
        );
      assert.deepEqual(verified, {
        purpose: 'DEVELOPER_EMAIL_TEST',
        verified: true,
      });
      assert.equal('resetGrant' in verified, false);
      assert.equal(
        await harness.userRepo.findByEmail('test.recipient@example.com'),
        null
      );
      await assert.rejects(
        () =>
          harness.emailAuthService.verifyDeveloperEmailTestOtp(
            result.challengeId,
            'test.recipient@example.com',
            message.otp
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'INVALID_EMAIL_OTP'
      );
    });
  });

  it('rejects expired, incorrect and exhausted developer OTPs', async () => {
    await withStagingEmailTestEnabled(async () => {
      const harness = createHarness();
      const expired = await harness.emailAuthService.sendDeveloperEmailTestOtp(
        'expired@example.com',
        '127.0.0.1'
      );
      harness.emailOtpRepo.expireChallengeForTesting(expired.challengeId);
      await assert.rejects(
        () =>
          harness.emailAuthService.verifyDeveloperEmailTestOtp(
            expired.challengeId,
            'expired@example.com',
            harness.sentMessages[0].otp
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'INVALID_EMAIL_OTP'
      );

      const exhausted =
        await harness.emailAuthService.sendDeveloperEmailTestOtp(
          'exhausted@example.com',
          '127.0.0.2'
        );
      for (let attempt = 0; attempt < 5; attempt += 1) {
        await assert.rejects(
          () =>
            harness.emailAuthService.verifyDeveloperEmailTestOtp(
              exhausted.challengeId,
              'exhausted@example.com',
              '000000'
            ),
          (error: unknown) =>
            error instanceof AppError &&
            error.errorCode === 'INVALID_EMAIL_OTP'
        );
      }
      const unaffected =
        await harness.emailAuthService.sendDeveloperEmailTestOtp(
            'unaffected@example.com'
        );
      await assert.rejects(
        () =>
          harness.emailAuthService.verifyDeveloperEmailTestOtp(
            exhausted.challengeId,
            'exhausted@example.com',
            harness.sentMessages[1].otp
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'INVALID_EMAIL_OTP'
      );
      await harness.emailAuthService.verifyDeveloperEmailTestOtp(
        unaffected.challengeId,
        'unaffected@example.com',
        harness.sentMessages[2].otp
      );
    });
  });

  it('sets the developer challenge expiry to exactly five minutes', async (context) => {
    const now = new Date('2026-03-01T00:00:00.000Z');
    context.mock.timers.enable({ apis: ['Date'], now });
    try {
      await withStagingEmailTestEnabled(async () => {
        const harness = createHarness();
        const result = await harness.emailAuthService.sendDeveloperEmailTestOtp(
          'expiry@example.com'
        );
        const challenge = await harness.emailOtpRepo.findActiveChallenge(
          result.challengeId,
          'expiry@example.com',
          'DEVELOPER_EMAIL_TEST',
          null
        );

        assert.equal(result.expiresInSeconds, 300);
        assert.equal(challenge?.expiresAt.getTime() - now.getTime(), 300_000);
      });
    } finally {
      context.mock.timers.reset();
    }
  });

  it('returns cooldown and expiry durations remaining after email delivery', async (context) => {
    context.mock.timers.enable({
      apis: ['Date'],
      now: new Date('2026-03-01T00:00:00.000Z'),
    });
    try {
      await withStagingEmailTestEnabled(async () => {
        const harness = createHarness({
          sendOtp: async () => {
            context.mock.timers.tick(7_000);
          },
        });
        const result = await harness.emailAuthService.sendDeveloperEmailTestOtp(
          'delayed@example.com'
        );

        assert.equal(result.retryAfterSeconds, 23);
        assert.equal(result.expiresInSeconds, 293);
      });
    } finally {
      context.mock.timers.reset();
    }
  });

  it('enforces the 30-second developer resend cooldown and then permits a resend', async (context) => {
    context.mock.timers.enable({
      apis: ['Date'],
      now: new Date('2026-03-01T00:00:00.000Z'),
    });
    try {
      await withStagingEmailTestEnabled(async () => {
        const harness = createHarness();
        const first =
          await harness.emailAuthService.sendDeveloperEmailTestOtp(
            'cooldown@example.com',
            '127.0.0.1'
          );
        const firstOtp = harness.sentMessages[0].otp;
        assert.equal(first.retryAfterSeconds, 30);

        await assert.rejects(
          () =>
            harness.emailAuthService.sendDeveloperEmailTestOtp(
              'cooldown@example.com',
              '127.0.0.1'
            ),
          (error: unknown) =>
            error instanceof AppError &&
            error.errorCode === 'EMAIL_OTP_COOLDOWN_ACTIVE' &&
            error.details?.retryAfterSeconds === 30
        );

        context.mock.timers.tick(30_000);
        const resent =
          await harness.emailAuthService.sendDeveloperEmailTestOtp(
            'cooldown@example.com',
            '127.0.0.1'
          );
        assert.equal(resent.retryAfterSeconds, 30);
        assert.equal(harness.sentMessages.length, 2);
        await assert.rejects(
          () =>
            harness.emailAuthService.verifyDeveloperEmailTestOtp(
              first.challengeId,
              'cooldown@example.com',
              firstOtp
            ),
          (error: unknown) =>
            error instanceof AppError &&
            error.errorCode === 'INVALID_EMAIL_OTP'
        );
      });
    } finally {
      context.mock.timers.reset();
    }
  });

  it('preserves the separate hourly developer email limit and remaining wait', async (context) => {
    context.mock.timers.enable({
      apis: ['Date'],
      now: new Date('2026-03-01T00:00:00.000Z'),
    });
    try {
      await withStagingEmailTestEnabled(async () => {
        const harness = createHarness();
        for (let index = 0; index < 5; index += 1) {
          await harness.emailAuthService.sendDeveloperEmailTestOtp(
            'hourly-limit@example.com',
            '127.0.0.1'
          );
          if (index < 4) context.mock.timers.tick(30_000);
        }

        await assert.rejects(
          () =>
            harness.emailAuthService.sendDeveloperEmailTestOtp(
              'hourly-limit@example.com',
              '127.0.0.1'
            ),
          (error: unknown) => {
            assert.ok(error instanceof AppError);
            assert.equal(error.errorCode, 'EMAIL_OTP_RATE_LIMITED');
            assert.deepEqual(error.details, {
              scope: 'email',
              retryAfterSeconds: 3480,
            });
            return true;
          }
        );
        assert.equal(harness.sentMessages.length, 5);
      });
    } finally {
      context.mock.timers.reset();
    }
  });

  it('uses configurable staging-only email and IP hourly limits', async (context) => {
    context.mock.timers.enable({
      apis: ['Date'],
      now: new Date('2026-03-01T00:00:00.000Z'),
    });
    try {
      await withStagingEmailTestEnabled(async () => {
        const emailHarness = createHarness();
        process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL =
          '2';
        process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP =
          '10';

        await emailHarness.emailAuthService.sendDeveloperEmailTestOtp(
          'config-limit@example.com'
        );
        context.mock.timers.tick(30_000);
        await emailHarness.emailAuthService.sendDeveloperEmailTestOtp(
          'config-limit@example.com'
        );
        await assert.rejects(
          () =>
            emailHarness.emailAuthService.sendDeveloperEmailTestOtp(
              'config-limit@example.com'
            ),
          (error: unknown) =>
            error instanceof AppError &&
            error.errorCode === 'EMAIL_OTP_RATE_LIMITED' &&
            error.details?.scope === 'email'
        );

        process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_EMAIL =
          '10';
        process.env.STAGING_DEVELOPER_EMAIL_OTP_MAX_REQUESTS_PER_HOUR_PER_IP =
          '2';
        const ipHarness = createHarness();
        for (let index = 0; index < 2; index += 1) {
          await ipHarness.emailAuthService.sendDeveloperEmailTestOtp(
            `ip-limit-${index}@example.com`,
            '127.0.0.2'
          );
        }
        await assert.rejects(
          () =>
            ipHarness.emailAuthService.sendDeveloperEmailTestOtp(
              'ip-limit-final@example.com',
              '127.0.0.2'
            ),
          (error: unknown) =>
            error instanceof AppError &&
            error.errorCode === 'EMAIL_OTP_RATE_LIMITED' &&
            error.details?.scope === 'ip'
        );
      });
    } finally {
      context.mock.timers.reset();
    }
  });

  it('preserves provider retry delays longer than the local resend cooldown', async () => {
    await withStagingEmailTestEnabled(async () => {
      const deliveryError = new AppError(
        'Brevo rate-limited transactional email delivery.',
        502,
        'BREVO_RATE_LIMITED',
        {
          provider: 'Brevo',
          httpStatus: 429,
          retryAfterSeconds: 120,
        }
      );
      const harness = createHarness({
        sendOtp: async () => {
          throw deliveryError;
        },
      });

      await assert.rejects(
        () =>
          harness.emailAuthService.sendDeveloperEmailTestOtp(
            'provider-limit@example.com',
            '127.0.0.1'
          ),
        (error: unknown) => {
          assert.ok(error instanceof AppError);
          assert.equal(error.errorCode, 'BREVO_RATE_LIMITED');
          assert.deepEqual(error.details, {
            provider: 'Brevo',
            httpStatus: 429,
            retryAfterSeconds: 120,
            providerRetryAfterSeconds: 120,
          });
          return true;
        }
      );
    });
  });

  it('isolates developer OTP purpose and enforces resend and IP rate limits', async () => {
    await withStagingEmailTestEnabled(async () => {
      const harness = createHarness();
      const request =
        await harness.emailAuthService.sendDeveloperEmailTestOtp(
          'purpose@example.com',
          '127.0.0.1'
        );
      await assert.rejects(
        () =>
          harness.emailAuthService.verifyOtp(
            request.challengeId,
            'purpose@example.com',
            'PASSWORD_RESET',
            harness.sentMessages[0].otp
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'INVALID_EMAIL_OTP'
      );
      await assert.rejects(
        () =>
          harness.emailAuthService.sendDeveloperEmailTestOtp(
            'purpose@example.com',
            '127.0.0.1'
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'EMAIL_OTP_COOLDOWN_ACTIVE'
      );

      const ipHarness = createHarness();
      for (let index = 0; index < 15; index += 1) {
        await ipHarness.emailAuthService.sendDeveloperEmailTestOtp(
          `recipient-${index}@example.com`,
          '127.0.0.10'
        );
      }
      await assert.rejects(
        () =>
          ipHarness.emailAuthService.sendDeveloperEmailTestOtp(
            'recipient-16@example.com',
            '127.0.0.10'
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'EMAIL_OTP_RATE_LIMITED'
      );
      assert.equal(ipHarness.sentMessages.length, 15);
    });
  });

  it('rejects developer email testing when disabled or running in production', async () => {
    const harness = createHarness();
    const previousAppEnv = process.env.APP_ENV;
    const previousNodeEnv = process.env.NODE_ENV;
    const previousEnabled =
      process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED;
    try {
      process.env.APP_ENV = 'staging';
      process.env.NODE_ENV = 'development';
      delete process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED;
      await assert.rejects(
        () =>
          harness.emailAuthService.sendDeveloperEmailTestOtp(
            'recipient@example.com'
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'DEVELOPER_EMAIL_OTP_TEST_DISABLED'
      );

      process.env.APP_ENV = 'production';
      process.env.NODE_ENV = 'production';
      process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED = 'true';
      await assert.rejects(
        () =>
          harness.emailAuthService.sendDeveloperEmailTestOtp(
            'recipient@example.com'
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'DEVELOPER_EMAIL_OTP_TEST_DISABLED'
      );
      assert.equal(harness.sentMessages.length, 0);
    } finally {
      if (previousAppEnv === undefined) delete process.env.APP_ENV;
      else process.env.APP_ENV = previousAppEnv;
      if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = previousNodeEnv;
      if (previousEnabled === undefined) {
        delete process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED;
      } else {
        process.env.STAGING_DEVELOPER_EMAIL_OTP_TEST_ENABLED =
          previousEnabled;
      }
    }
  });

  it('rejects initial activation when eligibility is unknown or partner-linked', async () => {
    const harness = createHarness();
    const unknownUser = await harness.userRepo.create({
      phone: '+919876500001',
    });
    const linkedUser = await harness.userRepo.create({
      phone: '+919876500002',
      emailPasswordEligibility: 'PARTNER_INELIGIBLE',
    });
    const pendingPartner = await createEligibleNewPatient(harness.userRepo);
    const activePartner = await createEligibleNewPatient(harness.userRepo);
    harness.userRepo.setPartnerInvitationPendingForTesting(
      pendingPartner.id,
      true
    );
    harness.userRepo.setPartnerMemberForTesting(activePartner.id, true);

    for (const user of [
      unknownUser,
      linkedUser,
      pendingPartner,
      activePartner,
    ]) {
      await assert.rejects(
        () =>
          harness.emailAuthService.sendActivationOtp(
            'patient@example.com',
            user.id
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'FORBIDDEN'
      );
    }
    await assert.rejects(
      () =>
        harness.emailAuthService.sendActivationOtp(
          'patient@example.com',
          undefined
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'UNAUTHORIZED'
    );
    assert.equal(harness.sentMessages.length, 0);
  });

  it('does not use EMAIL_CHANGE to attach the first email', async () => {
    const harness = createHarness();
    const user = await harness.userRepo.create({
      phone: '+919876500003',
    });

    await assert.rejects(
      () =>
        harness.emailAuthService.sendOtp(
          'first@example.com',
          'EMAIL_CHANGE',
          user.id
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'FORBIDDEN'
    );
    assert.equal(harness.sentMessages.length, 0);
  });

  it('rejects duplicate normalized email addresses during initial activation', async () => {
    const harness = createHarness();
    const owner = await createUserWithEmail(
      harness.userRepo,
      'taken@example.com',
      true
    );
    const eligibleUser = await createEligibleNewPatient(harness.userRepo);

    await assert.rejects(
      () =>
        harness.emailAuthService.sendActivationOtp(
          ' TAkEN@example.com ',
          eligibleUser.id
        ),
      ConflictError
    );
    assert.equal((await harness.userRepo.findById(eligibleUser.id))?.email, null);
    assert.equal(
      (await harness.userRepo.findByEmail('taken@example.com'))?.id,
      owner.id
    );
  });

  it('issues a one-time reset grant without changing the existing password', async () => {
    const harness = createHarness();
    const user = await createUserWithEmail(
      harness.userRepo,
      'patient@example.com',
      true,
      'existing-password-hash'
    );
    const request = await harness.emailAuthService.sendPasswordResetOtp(
      user.phone.substring(3),
      'patient@example.com'
    );
    const otp = harness.sentMessages[0].otp;
    const result = await harness.emailAuthService.verifyOtp(
      request.challengeId,
      'patient@example.com',
      'PASSWORD_RESET',
      otp
    );

    assert.equal(result.purpose, 'PASSWORD_RESET');
    if (result.purpose !== 'PASSWORD_RESET') {
      assert.fail('Expected a reset grant.');
    }
    assert.equal(result.expiresInSeconds, 600);
    assert.equal(
      (
        await harness.passwordResetGrantRepo.findActiveByHash(
          crypto.createHash('sha256').update(result.resetGrant).digest('hex')
        )
      )?.userId,
      user.id
    );
    assert.equal(
      (
        await harness.userRepo.findByEmailWithPasswordHash('patient@example.com')
      )?.passwordHash,
      'existing-password-hash'
    );
  });

  it('allows purpose-bound password reset for an unverified registration email without verifying it', async () => {
    const harness = createHarness();
    const user = await createEligibleNewPatient(harness.userRepo);
    await harness.userRepo.setInitialRegistrationCredentials(
      user.id,
      'new.patient@example.com',
      'existing-password-hash'
    );

    const request = await harness.emailAuthService.sendPasswordResetOtp(
      user.phone,
      'NEW.PATIENT@example.com'
    );
    const result = await harness.emailAuthService.verifyOtp(
      request.challengeId,
      'new.patient@example.com',
      'PASSWORD_RESET',
      harness.sentMessages[0].otp
    );
    assert.equal(result.purpose, 'PASSWORD_RESET');
    if (result.purpose !== 'PASSWORD_RESET') {
      assert.fail('Expected a reset grant.');
    }

    const grantHash = crypto
      .createHash('sha256')
      .update(result.resetGrant)
      .digest('hex');
    assert.equal(
      await harness.passwordResetGrantRepo.completePasswordReset(
        grantHash,
        'replacement-password-hash'
      ),
      true
    );
    const credentials = await harness.userRepo.findByIdWithPasswordHash(user.id);
    assert.equal(credentials?.passwordHash, 'replacement-password-hash');
    assert.equal(credentials?.user.emailVerifiedAt, null);
  });

  it('enforces a 30-second cooldown for concurrent resend requests', async () => {
    const harness = createHarness();
    const user = await createUserWithEmail(
      harness.userRepo,
      'patient@example.com',
      true,
      'existing-password-hash'
    );

    const results = await Promise.all(
      Array.from({ length: 6 }, () =>
        harness.emailAuthService.sendPasswordResetOtp(
          user.phone,
          'patient@example.com'
        )
      )
    );

    assert.equal(harness.sentMessages.length, 1);
    assert.ok(results.every((result) => result.retryAfterSeconds === 30));
    const activeChallenges = await Promise.all(
      results.map((result) =>
        harness.emailOtpRepo.findActiveChallenge(
          result.challengeId,
          'patient@example.com',
          'PASSWORD_RESET',
          user.id
        )
      )
    );
    assert.equal(activeChallenges.filter(Boolean).length, 1);
  });

  it('preserves Brevo diagnostics and returns the resend delay after delivery failure', async () => {
    const deliveryError = new AppError(
      'Brevo rejected the API request (HTTP 401): Invalid API key.',
      401,
      'BREVO_AUTHENTICATION_FAILED',
      {
        provider: 'Brevo',
        source: 'email_provider',
        httpStatus: 401,
        providerCode: 'unauthorized',
        providerMessage: 'Invalid API key.',
      }
    );
    const harness = createHarness({
      sendOtp: async () => {
        throw deliveryError;
      },
    });
    const user = await createUserWithEmail(
      harness.userRepo,
      'reset@example.com',
      true,
      'existing-password-hash'
    );

    await assert.rejects(
      () =>
        harness.emailAuthService.sendPasswordResetOtp(
          user.phone,
          'reset@example.com'
        ),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.errorCode, 'BREVO_AUTHENTICATION_FAILED');
        assert.equal(error.message, deliveryError.message);
        assert.deepEqual(error.details, {
          provider: 'Brevo',
          source: 'email_provider',
          httpStatus: 401,
          providerCode: 'unauthorized',
          providerMessage: 'Invalid API key.',
          retryAfterSeconds: 30,
        });
        assert.equal(error.statusCode, 401);
        return true;
      }
    );
  });

  it('returns indistinguishable send results for eligible and unknown public email requests', async () => {
    const harness = createHarness();
    const user = await createUserWithEmail(
      harness.userRepo,
      'reset@example.com',
      true,
      'existing-password-hash'
    );
    const knownReset = await harness.emailAuthService.sendPasswordResetOtp(
      user.phone,
      'reset@example.com'
    );
    const wrongEmailReset =
      await harness.emailAuthService.sendPasswordResetOtp(
        user.phone,
        'unknown-reset@example.com'
      );
    const wrongPhoneReset =
      await harness.emailAuthService.sendPasswordResetOtp(
        '+919876500000',
        'reset@example.com'
      );

    assert.deepEqual(
      Object.keys(knownReset).sort(),
      Object.keys(wrongEmailReset).sort()
    );
    assert.deepEqual(
      Object.keys(knownReset).sort(),
      Object.keys(wrongPhoneReset).sort()
    );
    assert.equal(knownReset.retryAfterSeconds, 30);
    assert.equal(wrongEmailReset.retryAfterSeconds, 30);
    assert.equal(wrongPhoneReset.retryAfterSeconds, 30);
    assert.equal(harness.sentMessages.length, 1);
    assert.equal(harness.sentMessages[0].email, 'reset@example.com');
  });

  it('only sends reset OTP to matching active patient accounts with a password', async () => {
    const harness = createHarness();
    const noPassword = await createUserWithEmail(
      harness.userRepo,
      'no-password@example.com',
      true
    );
    const partner = await createUserWithEmail(
      harness.userRepo,
      'partner@example.com',
      true,
      'partner-password-hash'
    );
    harness.userRepo.setPartnerMemberForTesting(partner.id, true);

    await harness.emailAuthService.sendPasswordResetOtp(
      noPassword.phone,
      'no-password@example.com'
    );
    await harness.emailAuthService.sendPasswordResetOtp(
      partner.phone,
      'partner@example.com'
    );

    assert.equal(harness.sentMessages.length, 0);
  });

  it('does not allow email-only password reset OTP requests', async () => {
    const harness = createHarness();

    await assert.rejects(
      () =>
        harness.emailAuthService.sendOtp(
          'patient@example.com',
          'PASSWORD_RESET'
        ),
      (error: unknown) =>
        error instanceof AppError && error.errorCode === 'VALIDATION_ERROR'
    );
    assert.equal(harness.sentMessages.length, 0);
  });
});

describe('Email OTP routes', () => {
  it('exposes a separate account-independent route only in enabled staging', async () => {
    await withStagingEmailTestEnabled(async () => {
      const harness = createHarness();
      const authService = new AuthService(
        harness.userRepo,
        new MockPatientProfileRepository(),
        new MockOtpRepository(),
        new MockRefreshTokenRepository(harness.userRepo),
        new DevelopmentSmsProvider(),
        { jwtAccessSecret: JWT_SECRET, otpSecret: OTP_SECRET }
      );
      const passwordAuthService = new PasswordAuthService(
        harness.userRepo,
        harness.passwordResetGrantRepo,
        new MockPasswordLoginRateLimitRepository(),
        authService,
        new BcryptPasswordHasher(),
        { rateLimitSecret: OTP_SECRET }
      );
      const app = express();
      app.use(express.json());
      app.use(
        '/api/v1/auth',
        createAuthRouter({
          authService,
          emailAuthService: harness.emailAuthService,
          passwordAuthService,
        })
      );
      app.use(errorHandler);
      const server = http.createServer(app);
      await new Promise<void>((resolve, reject) => {
        server.once('error', reject);
        server.listen(0, '127.0.0.1', resolve);
      });

      try {
        const address = server.address() as { port: number };
        const baseUrl = `http://127.0.0.1:${address.port}/api/v1/auth/email/developer-test/otp`;
        const sendResponse = await fetch(`${baseUrl}/send`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: 'unregistered@example.com' }),
        });
        assert.equal(sendResponse.status, 200);
        const sendBody = (await sendResponse.json()) as {
          message: string;
          data: { challengeId: string; retryAfterSeconds: number };
        };
        assert.match(sendBody.message, /Brevo accepted/);
        assert.equal(sendBody.data.retryAfterSeconds, 30);
        assert.equal(
          JSON.stringify(sendBody).includes(harness.sentMessages[0].otp),
          false
        );

        const verifyResponse = await fetch(`${baseUrl}/verify`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            challengeId: sendBody.data.challengeId,
            email: 'UNREGISTERED@example.com',
            otp: harness.sentMessages[0].otp,
          }),
        });
        assert.equal(verifyResponse.status, 200);
        const verifyBody = (await verifyResponse.json()) as {
          data: Record<string, unknown>;
        };
        assert.deepEqual(verifyBody.data, {
          purpose: 'DEVELOPER_EMAIL_TEST',
          verified: true,
        });
        assert.equal(await harness.userRepo.findByEmail('unregistered@example.com'), null);
        assert.equal(harness.sentMessages.length, 1);

        const passwordResetResponse = await fetch(
          `http://127.0.0.1:${address.port}/api/v1/auth/email/password/reset/otp/send`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              phone: '+919876500000',
              email: 'unregistered@example.com',
            }),
          }
        );
        assert.equal(passwordResetResponse.status, 200);
        const passwordResetBody = (await passwordResetResponse.json()) as {
          message: string;
          data: { challengeId: string; retryAfterSeconds: number };
        };
        assert.match(passwordResetBody.message, /If the account is eligible/);
        assert.equal(passwordResetBody.data.retryAfterSeconds, 30);
        assert.equal(harness.sentMessages.length, 1);

        process.env.APP_ENV = 'production';
        process.env.NODE_ENV = 'production';
        const productionAttempt = await fetch(`${baseUrl}/send`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: 'unregistered@example.com' }),
        });
        assert.equal(productionAttempt.status, 404);
        assert.equal(harness.sentMessages.length, 1);
      } finally {
        await new Promise<void>((resolve, reject) => {
          server.close((error) => (error ? reject(error) : resolve()));
        });
      }
    });
  });

  it('keeps EMAIL_CHANGE authenticated and binds initial activation to an eligible bearer user', async () => {
    const harness = createHarness();
    const profileRepo = new MockPatientProfileRepository();
    const otpRepo = new MockOtpRepository();
    const tokenRepo = new MockRefreshTokenRepository(harness.userRepo);
    const smsProvider = new DevelopmentSmsProvider();
    const authService = new AuthService(
      harness.userRepo,
      profileRepo,
      otpRepo,
      tokenRepo,
      smsProvider,
      {
        jwtAccessSecret: JWT_SECRET,
        otpSecret: OTP_SECRET,
      }
    );
    const passwordAuthService = new PasswordAuthService(
      harness.userRepo,
      harness.passwordResetGrantRepo,
      new MockPasswordLoginRateLimitRepository(),
      authService,
      new BcryptPasswordHasher(),
      { rateLimitSecret: OTP_SECRET }
    );
    const firstUser = await createUserWithEmail(
      harness.userRepo,
      'first@example.com',
      true
    );
    const secondUser = await createUserWithEmail(
      harness.userRepo,
      'second@example.com',
      true
    );
    const activationUser = await createEligibleNewPatient(harness.userRepo);
    const otherEligibleUser = await createEligibleNewPatient(harness.userRepo);
    const resetUser = await createUserWithEmail(
      harness.userRepo,
      'reset@example.com',
      true,
      'existing-password-hash'
    );

    const getMobileAccessToken = async (phone: string): Promise<string> => {
      const request = await authService.sendOtp(phone, 'LOGIN');
      const otp = smsProvider.sentMessages[smsProvider.sentMessages.length - 1].otp;
      const session = await authService.verifyOtp(
        request.challengeId,
        phone,
        'LOGIN',
        otp
      );
      return session.tokens.accessToken;
    };
    const firstToken = await getMobileAccessToken(firstUser.phone);
    const secondToken = await getMobileAccessToken(secondUser.phone);
    const activationToken = await getMobileAccessToken(activationUser.phone);
    const otherEligibleToken = await getMobileAccessToken(otherEligibleUser.phone);

    const app = express();
    app.use(express.json());
    app.use(
      createAuthRouter({
        authService,
        emailAuthService: harness.emailAuthService,
        passwordAuthService,
      })
    );
    app.use(errorHandler);
    const server = http.createServer(app);
    await new Promise<void>((resolve, reject) => {
      server.once('error', reject);
      server.listen(0, '127.0.0.1', resolve);
    });

    try {
      const address = server.address() as { port: number };
      const baseUrl = `http://127.0.0.1:${address.port}/email`;
      const sendBody = {
        email: 'new@example.com',
        purpose: 'EMAIL_CHANGE',
      };
      const unauthenticatedSend = await fetch(`${baseUrl}/otp/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(sendBody),
      });
      assert.equal(unauthenticatedSend.status, 401);
      assert.equal(harness.sentMessages.length, 0);

      const sendResponse = await fetch(`${baseUrl}/otp/send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${firstToken}`,
        },
        body: JSON.stringify(sendBody),
      });
      assert.equal(sendResponse.status, 200);
      const sendResult = (await sendResponse.json()) as {
        data: { challengeId: string };
      };
      const otp = harness.sentMessages[0].otp;
      assert.equal(JSON.stringify(sendResult).includes(otp), false);
      const verifyBody = {
        ...sendBody,
        challengeId: sendResult.data.challengeId,
        otp,
      };

      const secondUserVerify = await fetch(`${baseUrl}/otp/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${secondToken}`,
        },
        body: JSON.stringify(verifyBody),
      });
      assert.equal(secondUserVerify.status, 401);

      const unauthenticatedVerify = await fetch(`${baseUrl}/otp/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(verifyBody),
      });
      assert.equal(unauthenticatedVerify.status, 401);

      const firstUserVerify = await fetch(`${baseUrl}/otp/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${firstToken}`,
        },
        body: JSON.stringify(verifyBody),
      });
      assert.equal(firstUserVerify.status, 200);
      assert.equal(
        (await harness.userRepo.findByEmail('new@example.com'))?.id,
        firstUser.id
      );
      assert.equal(
        (await harness.userRepo.findByEmail('first@example.com')),
        null
      );

      const activationUrl = `${baseUrl}/activation/otp`;
      const activationBody = { email: 'activation@example.com' };
      const unauthenticatedActivation = await fetch(
        `${activationUrl}/send`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(activationBody),
        }
      );
      assert.equal(unauthenticatedActivation.status, 401);

      const genericActivation = await fetch(`${baseUrl}/otp/send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${activationToken}`,
        },
        body: JSON.stringify({
          email: 'activation@example.com',
          purpose: 'ACCOUNT_ACTIVATION',
        }),
      });
      assert.equal(genericActivation.status, 400);

      const activationSend = await fetch(`${activationUrl}/send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${activationToken}`,
        },
        body: JSON.stringify(activationBody),
      });
      assert.equal(activationSend.status, 200);
      const activationResult = (await activationSend.json()) as {
        data: { challengeId: string };
      };
      const activationOtp =
        harness.sentMessages[harness.sentMessages.length - 1]?.otp;
      assert.ok(activationOtp);
      assert.equal(
        JSON.stringify(activationResult).includes(activationOtp),
        false
      );

      const activationVerifyBody = {
        ...activationBody,
        challengeId: activationResult.data.challengeId,
        otp: activationOtp,
      };
      const otherUserVerify = await fetch(`${activationUrl}/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${otherEligibleToken}`,
        },
        body: JSON.stringify(activationVerifyBody),
      });
      assert.equal(otherUserVerify.status, 401);

      const unauthenticatedActivationVerify = await fetch(
        `${activationUrl}/verify`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(activationVerifyBody),
        }
      );
      assert.equal(unauthenticatedActivationVerify.status, 401);

      const activationVerify = await fetch(`${activationUrl}/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${activationToken}`,
        },
        body: JSON.stringify(activationVerifyBody),
      });
      assert.equal(activationVerify.status, 200);
      assert.equal(
        (await harness.userRepo.findByEmail('activation@example.com'))?.id,
        activationUser.id
      );

      const resetSendResponse = await fetch(
        `${baseUrl}/password/reset/otp/send`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            phone: resetUser.phone,
            email: 'reset@example.com',
          }),
        }
      );
      assert.equal(resetSendResponse.status, 200);
      const resetSendResult = (await resetSendResponse.json()) as {
        data: { challengeId: string };
      };
      const resetOtp =
        harness.sentMessages[harness.sentMessages.length - 1]?.otp;
      assert.ok(resetOtp);
      assert.equal(JSON.stringify(resetSendResult).includes(resetOtp), false);

      const resetVerifyResponse = await fetch(`${baseUrl}/otp/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'reset@example.com',
          purpose: 'PASSWORD_RESET',
          challengeId: resetSendResult.data.challengeId,
          otp: resetOtp,
        }),
      });
      assert.equal(resetVerifyResponse.status, 200);
      const resetVerifyResult = (await resetVerifyResponse.json()) as {
        data: {
          purpose: string;
          verified: boolean;
          resetGrant: string;
        };
      };
      assert.equal(resetVerifyResult.data.purpose, 'PASSWORD_RESET');
      assert.equal(resetVerifyResult.data.verified, true);
      assert.ok(resetVerifyResult.data.resetGrant.length > 0);
      assert.equal(
        JSON.stringify(resetVerifyResult).includes(resetOtp),
        false
      );
    } finally {
      await new Promise<void>((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    }
  });
});
