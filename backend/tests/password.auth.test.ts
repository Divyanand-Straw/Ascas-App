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
import { IEmailProvider } from '../src/modules/auth/email.provider.interface';
import { ISmsProvider } from '../src/modules/auth/sms.provider.interface';
import { createAuthRouter } from '../src/modules/auth/auth.routes';
import { errorHandler } from '../src/middleware/errorHandler';
import { AppError, ConflictError, ForbiddenError } from '../src/utils/errors';
import { BcryptPasswordHasher, IPasswordHasher } from '../src/modules/auth/password.hasher';
import { PasswordAuthService } from '../src/modules/auth/password.auth.service';

const JWT_SECRET = 'password_auth_test_jwt_secret_minimum_32_characters';
const OTP_SECRET = 'password_auth_test_otp_secret_minimum_32_characters';
const RATE_LIMIT_SECRET =
  'password_auth_test_rate_limit_secret_minimum_32_characters';
let nextTestPhone = 1;

class TestPasswordHasher implements IPasswordHasher {
  async hash(password: string): Promise<string> {
    return `test-hash:${password}`;
  }

  async verify(password: string, passwordHash: string): Promise<boolean> {
    return passwordHash === `test-hash:${password}`;
  }
}

function createHarness() {
  const userRepo = new MockUserRepository();
  const profileRepo = new MockPatientProfileRepository();
  const otpRepo = new MockOtpRepository();
  const refreshTokenRepo = new MockRefreshTokenRepository(userRepo);
  const resetGrantRepo = new MockPasswordResetGrantRepository(
    userRepo,
    refreshTokenRepo
  );
  const rateLimitRepo = new MockPasswordLoginRateLimitRepository();
  const sentSms: Array<{ phone: string; otp: string }> = [];
  const smsProvider: ISmsProvider = {
    sendOtp: async (phone, otp) => {
      sentSms.push({ phone, otp });
      return true;
    },
  };
  const sentEmails: Array<{ email: string; otp: string }> = [];
  const emailProvider: IEmailProvider = {
    sendOtp: async (email, otp) => {
      sentEmails.push({ email, otp });
    },
  };
  const authService = new AuthService(
    userRepo,
    profileRepo,
    otpRepo,
    refreshTokenRepo,
    smsProvider,
    {
      jwtAccessSecret: JWT_SECRET,
      otpSecret: OTP_SECRET,
    }
  );
  const emailAuthService = new EmailAuthService(
    userRepo,
    new MockEmailOtpRepository(),
    resetGrantRepo,
    emailProvider,
    { otpSecret: OTP_SECRET }
  );
  const passwordHasher = new TestPasswordHasher();
  const passwordAuthService = new PasswordAuthService(
    userRepo,
    resetGrantRepo,
    rateLimitRepo,
    authService,
    passwordHasher,
    { rateLimitSecret: RATE_LIMIT_SECRET }
  );

  return {
    userRepo,
    profileRepo,
    otpRepo,
    refreshTokenRepo,
    resetGrantRepo,
    rateLimitRepo,
    sentSms,
    sentEmails,
    authService,
    emailAuthService,
    passwordAuthService,
    passwordHasher,
  };
}

async function createUser(
  userRepo: MockUserRepository,
  email?: string,
  options: {
    verified?: boolean;
    passwordHash?: string;
    eligible?: boolean;
  } = {}
) {
  const suffix = (nextTestPhone++).toString().padStart(6, '0');
  const user = await userRepo.create({ phone: `+919876${suffix}` });
  if (options.eligible) {
    userRepo.setEmailPasswordEligibilityForTesting(
      user.id,
      'NEW_PATIENT_ELIGIBLE'
    );
  }
  if (email) {
    await userRepo.updateEmail(
      user.id,
      email,
      options.verified ? new Date() : null,
      null
    );
  }
  if (options.passwordHash) {
    await userRepo.setPasswordHash(user.id, options.passwordHash);
  }
  return user;
}

function createResetGrantToken(): string {
  return crypto.randomBytes(32).toString('base64url');
}

async function createServer(
  harness: ReturnType<typeof createHarness>
): Promise<{ server: http.Server; baseUrl: string }> {
  const app = express();
  app.use(express.json());
  app.use(
    createAuthRouter({
      authService: harness.authService,
      emailAuthService: harness.emailAuthService,
      passwordAuthService: harness.passwordAuthService,
    })
  );
  app.use(errorHandler);

  const server = http.createServer(app);
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address() as { port: number };
  return {
    server,
    baseUrl: `http://127.0.0.1:${address.port}/email/password`,
  };
}

async function closeServer(server: http.Server): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

describe('Password authentication', () => {
  it('lets a new mobile registration optionally verify an email and configure a password without linking a clinic profile', async () => {
    const harness = createHarness();
    const phone = '+919876543219';
    const mobileChallenge = await harness.authService.sendOtp(
      phone,
      'REGISTRATION'
    );
    const mobileOtp = harness.sentSms[0].otp;
    const session = await harness.authService.verifyOtp(
      mobileChallenge.challengeId,
      phone,
      'REGISTRATION',
      mobileOtp
    );

    assert.equal(
      (await harness.userRepo.findById(session.user.id))
        ?.emailPasswordEligibility,
      'NEW_PATIENT_ELIGIBLE'
    );
    assert.equal(session.profile, null);
    assert.equal(session.hasCompletedProfile, false);

    const emailChallenge = await harness.emailAuthService.sendActivationOtp(
      'new.patient@example.com',
      session.user.id
    );
    await harness.emailAuthService.verifyActivationOtp(
      emailChallenge.challengeId,
      'new.patient@example.com',
      harness.sentEmails[0].otp,
      session.user.id
    );
    await harness.passwordAuthService.setupPassword(
      session.user.id,
      'NewPatientSecurePass123'
    );

    const credentials = await harness.userRepo.findByEmailWithPasswordHash(
      'new.patient@example.com'
    );
    assert.equal(
      credentials?.passwordHash,
      'test-hash:NewPatientSecurePass123'
    );
    const emailSession = await harness.passwordAuthService.login(
      'NEW.PATIENT@example.com',
      'NewPatientSecurePass123'
    );
    assert.equal(emailSession.user.id, session.user.id);
    assert.equal(emailSession.profile, null);
    assert.equal(emailSession.hasCompletedProfile, false);
  });

  it('hashes and verifies passwords with bcrypt cost 12', async () => {
    const hasher = new BcryptPasswordHasher();
    const password = 'Correct horse battery staple';
    const hash = await hasher.hash(password);

    assert.match(hash, /^\$2[ab]\$12\$/);
    assert.notEqual(hash, password);
    assert.equal(await hasher.verify(password, hash), true);
    assert.equal(await hasher.verify('incorrect password', hash), false);
  });

  it('sets an initial password only after email verification', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo, undefined, {
      eligible: true,
    });
    const activation = await harness.emailAuthService.sendActivationOtp(
      'verified@example.com',
      user.id
    );
    await harness.emailAuthService.verifyActivationOtp(
      activation.challengeId,
      'verified@example.com',
      harness.sentEmails[0].otp,
      user.id
    );

    await harness.passwordAuthService.setupPassword(
      user.id,
      'Correct horse battery staple'
    );
    const credentials = await harness.userRepo.findByEmailWithPasswordHash(
      'verified@example.com'
    );
    assert.equal(
      credentials?.passwordHash,
      'test-hash:Correct horse battery staple'
    );
    assert.notEqual(
      credentials?.passwordHash,
      'Correct horse battery staple'
    );

    await assert.rejects(
      () =>
        harness.passwordAuthService.setupPassword(
          user.id,
          'Another secure password'
        ),
      (error: unknown) =>
        error instanceof ConflictError &&
        error.message === 'Password credentials are already configured.'
    );
  });

  it('creates normalized unverified registration credentials retry-safely without disabling mobile OTP', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo, undefined, {
      eligible: true,
    });
    const password = 'NewPatientSecurePass123';

    await harness.passwordAuthService.setupRegistrationCredentials(
      user.id,
      '  New.Patient@Example.COM ',
      password
    );

    const credentials = await harness.userRepo.findByIdWithPasswordHash(user.id);
    assert.equal(credentials?.user.email, 'new.patient@example.com');
    assert.equal(credentials?.user.emailVerifiedAt, null);
    assert.equal(credentials?.passwordHash, `test-hash:${password}`);
    assert.notEqual(credentials?.passwordHash, password);

    await harness.passwordAuthService.setupRegistrationCredentials(
      user.id,
      'NEW.PATIENT@example.com',
      password
    );
    await assert.rejects(
      () =>
        harness.passwordAuthService.setupRegistrationCredentials(
          user.id,
          'new.patient@example.com',
          'DifferentSecurePass123'
        ),
      ConflictError
    );

    const mobileChallenge = await harness.authService.sendOtp(
      user.phone,
      'LOGIN'
    );
    const mobileSession = await harness.authService.verifyOtp(
      mobileChallenge.challengeId,
      user.phone,
      'LOGIN',
      harness.sentSms[harness.sentSms.length - 1].otp
    );
    assert.equal(mobileSession.user.id, user.id);

    const emailSession = await harness.passwordAuthService.login(
      ' NEW.PATIENT@EXAMPLE.COM ',
      password
    );
    assert.equal(emailSession.user.id, user.id);
    assert.equal(emailSession.profile, null);
    assert.equal(emailSession.hasCompletedProfile, false);
  });

  it('returns the same persisted patient profile for mobile OTP and email/password login', async () => {
    const harness = createHarness();
    const phone = '+919876543219';
    const registrationChallenge = await harness.authService.sendOtp(
      phone,
      'REGISTRATION'
    );
    const registrationSession = await harness.authService.verifyOtp(
      registrationChallenge.challengeId,
      phone,
      'REGISTRATION',
      harness.sentSms[0].otp
    );
    const email = 'new.patient@example.com';
    const password = 'NewPatientSecurePass123';

    await harness.passwordAuthService.setupRegistrationCredentials(
      registrationSession.user.id,
      `  ${email.toUpperCase()} `,
      password
    );
    const credentials = await harness.userRepo.findByIdWithPasswordHash(
      registrationSession.user.id
    );
    assert.equal(credentials?.user.email, email);
    assert.equal(credentials?.user.emailVerifiedAt, null);
    assert.notEqual(credentials?.passwordHash, password);

    const profile = await harness.authService.createOrGetPatientProfile(
      registrationSession.user.id,
      {
        firstName: 'Priya',
        lastName: 'Sharma',
        dob: new Date('1994-06-15T00:00:00.000Z'),
        emergencyContact: '+919123456789',
        preferredLanguage: 'ta',
      }
    );
    const retry = await harness.authService.createOrGetPatientProfile(
      registrationSession.user.id,
      {
        firstName: 'Changed',
        lastName: 'Name',
        dob: new Date('2000-01-01T00:00:00.000Z'),
        emergencyContact: '+919123456789',
        preferredLanguage: 'en',
      }
    );
    assert.equal(retry.id, profile.id);
    assert.equal(retry.firstName, 'Priya');
    assert.equal(profile.userId, registrationSession.user.id);

    const mobileChallenge = await harness.authService.sendOtp(phone, 'LOGIN');
    const mobileSession = await harness.authService.verifyOtp(
      mobileChallenge.challengeId,
      phone,
      'LOGIN',
      harness.sentSms[1].otp
    );
    const emailSession = await harness.passwordAuthService.login(
      ' NEW.PATIENT@EXAMPLE.COM ',
      password
    );

    assert.equal(mobileSession.user.id, registrationSession.user.id);
    assert.equal(mobileSession.user.email, email);
    assert.equal(mobileSession.user.phone, phone);
    assert.equal(emailSession.user.id, registrationSession.user.id);
    assert.equal(emailSession.user.email, email);
    assert.equal(emailSession.user.phone, phone);
    assert.equal(mobileSession.profile?.id, profile.id);
    assert.equal(emailSession.profile?.id, profile.id);
    assert.equal(mobileSession.profile?.firstName, profile.firstName);
    assert.equal(mobileSession.profile?.lastName, profile.lastName);
    assert.equal(mobileSession.profile?.dob, '1994-06-15');
    assert.equal(emailSession.profile?.firstName, 'Priya');
    assert.equal(emailSession.profile?.lastName, 'Sharma');
    assert.equal(emailSession.profile?.dob, '1994-06-15');
    assert.equal(
      mobileSession.profile?.emergencyContact,
      profile.emergencyContact
    );
    assert.equal(emailSession.profile?.emergencyContact, '+919123456789');
    assert.equal(
      (await harness.userRepo.findByPhone(phone))?.id,
      registrationSession.user.id
    );
    assert.equal(
      (await harness.userRepo.findByEmail(email))?.id,
      registrationSession.user.id
    );
    assert.equal(
      (await harness.userRepo.findById(registrationSession.user.id))?.phone,
      phone
    );
    assert.equal(
      harness.userRepo.isPhoneVerifiedForTesting(registrationSession.user.id),
      true
    );
    assert.equal(
      (await harness.userRepo.findById(registrationSession.user.id))
        ?.emailVerifiedAt,
      null
    );
  });

  it('keeps existing OTP-only patients ineligible without authoritative clinic verification', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo);
    const challenge = await harness.authService.sendOtp(user.phone, 'LOGIN');
    const mobileSession = await harness.authService.verifyOtp(
      challenge.challengeId,
      user.phone,
      'LOGIN',
      harness.sentSms[0].otp
    );

    await assert.rejects(
      () =>
        harness.emailAuthService.sendActivationOtp(
          'otp-only@example.com',
          mobileSession.user.id
        ),
      (error: unknown) =>
        error instanceof ForbiddenError
    );
    await assert.rejects(
      () =>
        harness.passwordAuthService.setupPassword(
          mobileSession.user.id,
          'Correct horse battery staple'
        ),
      (error: unknown) => error instanceof ForbiddenError
    );
    assert.equal(
      (await harness.userRepo.findByEmail('otp-only@example.com')),
      null
    );
    assert.equal(mobileSession.user.id, user.id);
  });

  it('rejects password setup for an unverified email', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo, 'pending@example.com', {
      eligible: true,
    });

    await assert.rejects(
      () =>
        harness.passwordAuthService.setupPassword(
          user.id,
          'Correct horse battery staple'
        ),
      (error: unknown) =>
        error instanceof ForbiddenError &&
        error.message === 'A verified email is required to set a password.'
    );
  });

  it('preserves normalized email uniqueness when activating another account', async () => {
    const harness = createHarness();
    const first = await createUser(harness.userRepo);
    const second = await createUser(harness.userRepo);
    await harness.userRepo.updateEmail(
      first.id,
      'patient@example.com',
      new Date(),
      null
    );

    await assert.rejects(
      () =>
        harness.userRepo.updateEmail(
          second.id,
          ' PATIENT@EXAMPLE.COM ',
          new Date(),
          null
        ),
      ConflictError
    );
  });

  it('authenticates with normalized email and reuses the access/refresh session lifecycle', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo, 'login@example.com', {
      verified: true,
      passwordHash: 'test-hash:Correct horse battery staple',
      eligible: true,
    });
    await harness.profileRepo.create({
      userId: user.id,
      firstName: 'Priya',
      lastName: 'Sharma',
    });

    const session = await harness.passwordAuthService.login(
      ' Login@Example.COM ',
      'Correct horse battery staple',
      'Test Device',
      '192.0.2.10'
    );
    assert.equal(session.user.id, user.id);
    assert.equal(session.profile?.firstName, 'Priya');
    assert.equal(
      harness.authService.verifyAccessToken(session.tokens.accessToken).sub,
      user.id
    );

    const oldTokenHash = crypto
      .createHash('sha256')
      .update(session.tokens.refreshToken)
      .digest('hex');
    const rotated = await harness.authService.refreshTokens(
      session.tokens.refreshToken
    );
    assert.ok(
      (await harness.refreshTokenRepo.findByTokenHash(oldTokenHash))?.revokedAt
    );

    await harness.authService.logout(rotated.refreshToken, user.id);
    const newTokenHash = crypto
      .createHash('sha256')
      .update(rotated.refreshToken)
      .digest('hex');
    assert.ok(
      (await harness.refreshTokenRepo.findByTokenHash(newTokenHash))?.revokedAt
    );
  });

  it('returns the same generic failure for unknown, wrong-password, disabled, and unverified accounts', async () => {
    const harness = createHarness();
    await createUser(harness.userRepo, 'active@example.com', {
      verified: true,
      passwordHash: 'test-hash:Correct horse battery staple',
      eligible: true,
    });
    const disabled = await createUser(
      harness.userRepo,
      'disabled@example.com',
      {
        verified: true,
        passwordHash: 'test-hash:Correct horse battery staple',
        eligible: true,
      }
    );
    await harness.userRepo.updateStatus(disabled.id, 'SUSPENDED');
    await createUser(harness.userRepo, 'unverified@example.com');

    const failures = await Promise.all(
      [
        ['active@example.com', 'incorrect password'],
        ['unknown@example.com', 'incorrect password'],
        ['disabled@example.com', 'Correct horse battery staple'],
        ['unverified@example.com', 'Correct horse battery staple'],
      ].map(async ([email, password]) => {
        try {
          await harness.passwordAuthService.login(
            email,
            password,
            undefined,
            '192.0.2.20'
          );
          assert.fail('Expected login to fail.');
        } catch (error: unknown) {
          assert.ok(error instanceof AppError);
          return {
            code: error.errorCode,
            message: error.message,
            status: error.statusCode,
          };
        }
      })
    );

    assert.deepEqual(new Set(failures.map((failure) => failure.code)).size, 1);
    assert.deepEqual(
      new Set(failures.map((failure) => failure.message)).size,
      1
    );
    assert.deepEqual(new Set(failures.map((failure) => failure.status)).size, 1);
    assert.equal(failures[0].status, 401);
  });

  it('rejects partner-linked accounts from password setup and login', async () => {
    const harness = createHarness();
    const setupPartner = await createUser(
      harness.userRepo,
      'setup-partner@example.com',
      { verified: true, eligible: true }
    );
    const loginPartner = await createUser(
      harness.userRepo,
      'login-partner@example.com',
      {
        verified: true,
        passwordHash: 'test-hash:Correct horse battery staple',
        eligible: true,
      }
    );
    harness.userRepo.setPartnerMemberForTesting(setupPartner.id, true);
    harness.userRepo.setPartnerMemberForTesting(loginPartner.id, true);

    await assert.rejects(
      () =>
        harness.passwordAuthService.setupPassword(
          setupPartner.id,
          'Another secure password'
        ),
      (error: unknown) =>
        error instanceof ForbiddenError &&
        error.message ===
          'This account is not eligible for email/password credentials.'
    );

    const pendingPartner = await createUser(
      harness.userRepo,
      'pending-partner@example.com',
      {
        verified: true,
        passwordHash: 'test-hash:Correct horse battery staple',
        eligible: true,
      }
    );
    harness.userRepo.setPartnerInvitationPendingForTesting(
      pendingPartner.id,
      true
    );
    await assert.rejects(
      () =>
        harness.passwordAuthService.setupPassword(
          pendingPartner.id,
          'Another secure password'
        ),
      (error: unknown) =>
        error instanceof ForbiddenError &&
        error.message ===
          'This account is not eligible for email/password credentials.'
    );
    await assert.rejects(
      () =>
        harness.passwordAuthService.login(
          'pending-partner@example.com',
          'Correct horse battery staple'
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'EMAIL_PASSWORD_INVALID_CREDENTIALS'
    );
    await assert.rejects(
      () =>
        harness.passwordAuthService.login(
          'login-partner@example.com',
          'Correct horse battery staple'
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'EMAIL_PASSWORD_INVALID_CREDENTIALS'
    );
  });

  it('rate limits password login attempts per email and source IP', async () => {
    const harness = createHarness();
    await createUser(harness.userRepo, 'limited@example.com', {
      verified: true,
      passwordHash: 'test-hash:Correct horse battery staple',
      eligible: true,
    });

    for (let attempt = 0; attempt < 5; attempt += 1) {
      await assert.rejects(
        () =>
          harness.passwordAuthService.login(
            'limited@example.com',
            'incorrect password',
            undefined,
            '192.0.2.30'
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'EMAIL_PASSWORD_INVALID_CREDENTIALS'
      );
    }
    await assert.rejects(
      () =>
        harness.passwordAuthService.login(
          'limited@example.com',
          'incorrect password',
          undefined,
          '192.0.2.30'
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'LOGIN_RATE_LIMIT_EXCEEDED' &&
        error.statusCode === 429
    );
  });

  it('uses a valid reset grant once and revokes existing refresh sessions', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo, 'reset@example.com', {
      verified: true,
      passwordHash: 'test-hash:Old secure password',
      eligible: true,
    });
    const credentials = await harness.userRepo.findByIdWithPasswordHash(
      user.id
    );
    assert.ok(credentials?.passwordHash);
    const session = await harness.authService.createEmailPasswordSession(
      user.id,
      credentials.passwordHash
    );
    const resetRequest = await harness.emailAuthService.sendPasswordResetOtp(
      user.phone,
      'reset@example.com'
    );
    const resetResult = await harness.emailAuthService.verifyOtp(
      resetRequest.challengeId,
      'reset@example.com',
      'PASSWORD_RESET',
      harness.sentEmails[0].otp
    );
    assert.equal(resetResult.purpose, 'PASSWORD_RESET');
    if (resetResult.purpose !== 'PASSWORD_RESET') {
      assert.fail('Expected a password reset grant.');
    }
    const grantToken = resetResult.resetGrant;
    const grantHash = crypto
      .createHash('sha256')
      .update(grantToken)
      .digest('hex');
    const anotherGrantHash = crypto
      .createHash('sha256')
      .update(createResetGrantToken())
      .digest('hex');
    await harness.resetGrantRepo.create({
      userId: user.id,
      grantHash: anotherGrantHash,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    });

    await harness.passwordAuthService.completePasswordReset(
      grantToken,
      'New secure password'
    );
    const updatedCredentials = await harness.userRepo.findByEmailWithPasswordHash(
      'reset@example.com'
    );
    assert.equal(
      updatedCredentials?.passwordHash,
      'test-hash:New secure password'
    );

    const refreshHash = crypto
      .createHash('sha256')
      .update(session.tokens.refreshToken)
      .digest('hex');
    assert.ok(
      (await harness.refreshTokenRepo.findByTokenHash(refreshHash))?.revokedAt
    );
    assert.equal(await harness.resetGrantRepo.findActiveByHash(grantHash), null);
    assert.equal(
      await harness.resetGrantRepo.findActiveByHash(anotherGrantHash),
      null
    );
    await assert.rejects(
      () =>
        harness.passwordAuthService.completePasswordReset(
          grantToken,
          'Another secure password'
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'INVALID_PASSWORD_RESET_GRANT'
    );
  });

  it('rejects invalid and expired reset grants with the same response', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo, 'expired@example.com', {
      verified: true,
      passwordHash: 'test-hash:Old secure password',
      eligible: true,
    });
    const expiredToken = createResetGrantToken();
    const expiredHash = crypto
      .createHash('sha256')
      .update(expiredToken)
      .digest('hex');
    await harness.resetGrantRepo.create({
      userId: user.id,
      grantHash: expiredHash,
      expiresAt: new Date(Date.now() - 1000),
    });

    const failures = await Promise.all(
      [expiredToken, createResetGrantToken()].map(async (resetGrant) => {
        try {
          await harness.passwordAuthService.completePasswordReset(
            resetGrant,
            'New secure password'
          );
          assert.fail('Expected reset grant to be rejected.');
        } catch (error: unknown) {
          assert.ok(error instanceof AppError);
          return { code: error.errorCode, message: error.message };
        }
      })
    );
    assert.deepEqual(failures[0], failures[1]);
  });

  it('exposes authenticated setup and email/password login routes', async () => {
    const harness = createHarness();
    const user = await createUser(harness.userRepo, undefined, {
      eligible: true,
    });
    const mobileChallenge = await harness.authService.sendOtp(
      user.phone,
      'LOGIN'
    );
    const mobileSession = await harness.authService.verifyOtp(
      mobileChallenge.challengeId,
      user.phone,
      'LOGIN',
      harness.sentSms[0].otp
    );
    const activation = await harness.emailAuthService.sendActivationOtp(
      'route@example.com',
      mobileSession.user.id
    );
    await harness.emailAuthService.verifyActivationOtp(
      activation.challengeId,
      'route@example.com',
      harness.sentEmails[0].otp,
      mobileSession.user.id
    );

    const { server, baseUrl } = await createServer(harness);
    try {
      const unauthenticatedSetup = await fetch(`${baseUrl}/setup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: 'Correct horse battery staple' }),
      });
      assert.equal(unauthenticatedSetup.status, 401);

      const setup = await fetch(`${baseUrl}/setup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${mobileSession.tokens.accessToken}`,
        },
        body: JSON.stringify({ password: 'Correct horse battery staple' }),
      });
      assert.equal(setup.status, 200);

      const login = await fetch(`${baseUrl}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'ROUTE@example.com',
          password: 'Correct horse battery staple',
          deviceInfo: 'Test Device',
        }),
      });
      assert.equal(login.status, 200);
      const loginBody = (await login.json()) as {
        data: { tokens: { accessToken: string; refreshToken: string } };
      };
      assert.ok(loginBody.data.tokens.accessToken);
      assert.ok(loginBody.data.tokens.refreshToken);

      const me = await fetch(`${baseUrl.replace('/email/password', '')}/me`, {
        headers: {
          Authorization: `Bearer ${loginBody.data.tokens.accessToken}`,
        },
      });
      assert.equal(me.status, 200);

      const resetRequest = await harness.emailAuthService.sendPasswordResetOtp(
        user.phone,
        'route@example.com'
      );
      const resetResult = await harness.emailAuthService.verifyOtp(
        resetRequest.challengeId,
        'route@example.com',
        'PASSWORD_RESET',
        harness.sentEmails[harness.sentEmails.length - 1].otp
      );
      assert.equal(resetResult.purpose, 'PASSWORD_RESET');
      if (resetResult.purpose !== 'PASSWORD_RESET') {
        assert.fail('Expected a password reset grant.');
      }
      const reset = await fetch(`${baseUrl}/reset`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resetGrant: resetResult.resetGrant,
          newPassword: 'New secure password',
        }),
      });
      assert.equal(reset.status, 200);

      const refresh = await fetch(
        `${baseUrl.replace('/email/password', '')}/token/refresh`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            refreshToken: loginBody.data.tokens.refreshToken,
          }),
        }
      );
      assert.equal(refresh.status, 401);
    } finally {
      await closeServer(server);
    }
  });

  it('sets registration credentials for the authenticated OTP subject and rejects client identity fields', async () => {
    const harness = createHarness();
    const phone = '+919876123456';
    const challenge = await harness.authService.sendOtp(phone, 'REGISTRATION');
    const session = await harness.authService.verifyOtp(
      challenge.challengeId,
      phone,
      'REGISTRATION',
      harness.sentSms[0].otp
    );
    const { server, baseUrl } = await createServer(harness);
    try {
      const setup = await fetch(`${baseUrl}/registration-setup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.tokens.accessToken}`,
        },
        body: JSON.stringify({
          email: '  ROUTE.NEW@Example.COM ',
          password: 'Correct horse battery staple',
        }),
      });
      assert.equal(setup.status, 200);

      const credentials = await harness.userRepo.findByIdWithPasswordHash(
        session.user.id
      );
      assert.equal(credentials?.user.email, 'route.new@example.com');
      assert.equal(credentials?.user.emailVerifiedAt, null);
      assert.notEqual(
        credentials?.passwordHash,
        'Correct horse battery staple'
      );

      const conflictingIdentity = await fetch(
        `${baseUrl}/registration-setup`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${session.tokens.accessToken}`,
          },
          body: JSON.stringify({
            userId: 'another-account',
            email: 'other@example.com',
            password: 'Correct horse battery staple',
          }),
        }
      );
      assert.equal(conflictingIdentity.status, 400);
      assert.equal(
        (await harness.userRepo.findByIdWithPasswordHash(session.user.id))
          ?.user.email,
        'route.new@example.com'
      );
    } finally {
      await closeServer(server);
    }
  });
});
