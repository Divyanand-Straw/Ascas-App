import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import jwt from 'jsonwebtoken';
import { AuthService } from '../src/modules/auth/auth.service';
import {
  MockUserRepository,
  MockPatientProfileRepository,
  MockOtpRepository,
  MockRefreshTokenRepository,
} from '../src/modules/auth/mock.auth.repository';
import { DevelopmentSmsProvider } from '../src/modules/auth/sms.provider';
import { AppError } from '../src/utils/errors';
import { createAuthRouter, getDefaultAuthService } from '../src/modules/auth/auth.routes';

describe('ASCAS Phase 1 Backend Phone OTP Authentication Tests', () => {
  let userRepo: MockUserRepository;
  let profileRepo: MockPatientProfileRepository;
  let otpRepo: MockOtpRepository;
  let tokenRepo: MockRefreshTokenRepository;
  let smsProvider: DevelopmentSmsProvider;
  let authService: AuthService;

  const testConfig = {
    jwtAccessSecret: 'test_jwt_access_secret_minimum_32_characters_long_12345!',
    otpSecret: 'test_otp_secret_minimum_32_characters_long_12345!',
    resendCooldownSeconds: 45,
    otpExpiresInMinutes: 5,
    maxOtpAttempts: 3,
    maxRequestsPerHourPerPhone: 5,
    maxRequestsPerHourPerIp: 15,
  };

  beforeEach(() => {
    userRepo = new MockUserRepository();
    profileRepo = new MockPatientProfileRepository();
    otpRepo = new MockOtpRepository();
    tokenRepo = new MockRefreshTokenRepository();
    smsProvider = new DevelopmentSmsProvider();

    authService = new AuthService(
      userRepo,
      profileRepo,
      otpRepo,
      tokenRepo,
      smsProvider,
      testConfig
    );
  });

  // --------------------------------------------------------------------------
  // 1. OTP Generation
  // --------------------------------------------------------------------------
  it('should generate a 6-digit cryptographically secure OTP between 100000 and 999999', () => {
    for (let i = 0; i < 50; i++) {
      const otp = authService.generateOtp();
      assert.match(otp, /^\d{6}$/, `OTP ${otp} is not a 6-digit number`);
      const num = parseInt(otp, 10);
      assert.ok(num >= 100000 && num <= 999999, `OTP ${num} out of bounds`);
    }
  });

  // --------------------------------------------------------------------------
  // 2. OTP Hashing
  // --------------------------------------------------------------------------
  it('should generate deterministic HMAC-SHA256 OTP hashes bound to phone and purpose', () => {
    const hash1 = authService.hashOtp('+919876543210', 'LOGIN', '123456');
    const hash2 = authService.hashOtp('+919876543210', 'LOGIN', '123456');
    const hashDiffPurpose = authService.hashOtp('+919876543210', 'REGISTRATION', '123456');
    const hashDiffPhone = authService.hashOtp('+919123456780', 'LOGIN', '123456');

    assert.equal(hash1, hash2, 'Identical inputs must yield identical HMAC hashes');
    assert.notEqual(hash1, hashDiffPurpose, 'Hashes must differ across purposes');
    assert.notEqual(hash1, hashDiffPhone, 'Hashes must differ across phone numbers');
    assert.equal(hash1.length, 64, 'HMAC-SHA256 digest must be 64 hex characters');
  });

  // --------------------------------------------------------------------------
  // 3. Successful Verification (REGISTRATION & LOGIN)
  // --------------------------------------------------------------------------
  it('should successfully register a new patient upon valid OTP verification', async () => {
    const phone = '+919876543210';
    const sendResult = await authService.sendOtp(phone, 'REGISTRATION', '192.168.1.1');

    assert.ok(sendResult.challengeId, 'Must return challenge ID');
    assert.equal(sendResult.expiresInSeconds, 300);
    assert.equal(sendResult.retryAfterSeconds, 45);

    const sentOtp = smsProvider.sentMessages[0].otp;
    const session = await authService.verifyOtp(
      sendResult.challengeId,
      phone,
      'REGISTRATION',
      sentOtp,
      'Test Device'
    );

    assert.equal(session.user.phone, phone);
    assert.equal(session.user.role, 'PATIENT');
    assert.equal(session.user.status, 'ACTIVE');
    assert.equal(session.isNewUser, true);
    assert.equal(session.hasCompletedProfile, false);
    assert.ok(session.tokens.accessToken, 'Access token must be present');
    assert.ok(session.tokens.refreshToken, 'Refresh token must be present');
  });

  it('should successfully log in an existing active patient upon valid OTP verification', async () => {
    const phone = '+919876543210';
    const user = await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });
    await profileRepo.create({
      userId: user.id,
      firstName: 'Priya',
      lastName: 'Sharma',
      preferredLanguage: 'en',
    });

    const sendResult = await authService.sendOtp(phone, 'LOGIN', '192.168.1.1');
    const sentOtp = smsProvider.sentMessages[0].otp;

    const session = await authService.verifyOtp(
      sendResult.challengeId,
      phone,
      'LOGIN',
      sentOtp
    );

    assert.equal(session.user.id, user.id);
    assert.equal(session.isNewUser, false);
    assert.equal(session.hasCompletedProfile, true);
    assert.equal(session.profile?.firstName, 'Priya');
    assert.equal(session.profile?.lastName, 'Sharma');
  });

  // --------------------------------------------------------------------------
  // 4. Incorrect OTP & Attempt Count Decrement
  // --------------------------------------------------------------------------
  it('should reject an incorrect OTP and decrement remaining attempts', async () => {
    const phone = '+919876543210';
    const sendResult = await authService.sendOtp(phone, 'REGISTRATION');
    const sentOtp = smsProvider.sentMessages[0].otp;
    const wrongOtp = sentOtp === '111111' ? '222222' : '111111';

    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', wrongOtp);
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 401);
        assert.equal(err.errorCode, 'INVALID_OTP');
        const details = err.details as { remainingAttempts: number };
        assert.equal(details.remainingAttempts, 2);
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 5. Expired OTP
  // --------------------------------------------------------------------------
  it('should reject an expired OTP challenge', async () => {
    const phone = '+919876543210';
    const sendResult = await authService.sendOtp(phone, 'REGISTRATION');
    const sentOtp = smsProvider.sentMessages[0].otp;

    // Fast-forward challenge expiry
    otpRepo.expireChallengeForTesting(sendResult.challengeId);

    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', sentOtp);
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 401);
        assert.equal(err.errorCode, 'OTP_EXPIRED');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 6. Reused OTP (Single-Use Challenge)
  // --------------------------------------------------------------------------
  it('should reject subsequent verification attempts once OTP is consumed (single-use)', async () => {
    const phone = '+919876543210';
    const sendResult = await authService.sendOtp(phone, 'REGISTRATION');
    const sentOtp = smsProvider.sentMessages[0].otp;

    // First verification succeeds
    await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', sentOtp);

    // Second attempt with same challenge ID fails
    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', sentOtp);
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 401);
        assert.equal(err.errorCode, 'OTP_ALREADY_USED');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 7. Three-Attempt Lockout
  // --------------------------------------------------------------------------
  it('should lock out the challenge on the 3rd failed attempt', async () => {
    const phone = '+919876543210';
    const sendResult = await authService.sendOtp(phone, 'REGISTRATION');

    // Attempt 1
    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', '000001');
      },
      (err: AppError) => err.errorCode === 'INVALID_OTP'
    );

    // Attempt 2
    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', '000002');
      },
      (err: AppError) => err.errorCode === 'INVALID_OTP'
    );

    // Attempt 3: Triggers lockout
    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', '000003');
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 403);
        assert.equal(err.errorCode, 'MAX_ATTEMPTS_EXCEEDED');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 8. Resend Cooldown
  // --------------------------------------------------------------------------
  it('should enforce 45-second resend cooldown before allowing another OTP send', async () => {
    const phone = '+919876543210';
    await authService.sendOtp(phone, 'REGISTRATION');

    // Immediate second send fails with COOLDOWN_ACTIVE
    await assert.rejects(
      async () => {
        await authService.sendOtp(phone, 'REGISTRATION');
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 429);
        assert.equal(err.errorCode, 'COOLDOWN_ACTIVE');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 9. Phone Rate Limits (5 requests / hour)
  // --------------------------------------------------------------------------
  it('should block OTP send when phone hourly limit (5 requests) is exceeded', async () => {
    const phone = '+919876543210';

    // Seed 5 requests within the past hour, but older than the 45-second cooldown
    for (let i = 0; i < 5; i++) {
      await otpRepo.create({
        phone,
        otpHash: 'dummy_hash',
        purpose: 'REGISTRATION',
        expiresAt: new Date(Date.now() + 5 * 60 * 1000),
        createdAt: new Date(Date.now() - (60 + i * 10) * 1000), // 60s+ ago
      });
    }

    await assert.rejects(
      async () => {
        await authService.sendOtp(phone, 'REGISTRATION');
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 429);
        assert.equal(err.errorCode, 'PHONE_RATE_LIMIT_EXCEEDED');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 10. IP Rate Limits (15 requests / hour)
  // --------------------------------------------------------------------------
  it('should block OTP send when IP hourly limit (15 requests) is exceeded', async () => {
    const ip = '10.0.0.42';

    // Seed 15 requests for this IP with different phones
    for (let i = 0; i < 15; i++) {
      await otpRepo.create({
        phone: `+9198765432${i.toString().padStart(2, '0')}`,
        otpHash: 'dummy_hash',
        purpose: 'REGISTRATION',
        expiresAt: new Date(Date.now() + 5 * 60 * 1000),
        ipAddress: ip,
      });
    }

    await assert.rejects(
      async () => {
        await authService.sendOtp('+919999999999', 'REGISTRATION', ip);
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 429);
        assert.equal(err.errorCode, 'RATE_LIMIT_EXCEEDED');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 11. LOGIN with Unknown Account
  // --------------------------------------------------------------------------
  it('should not dispatch SMS for unknown LOGIN phone but return consistent response, then reject on verify', async () => {
    const phone = '+919999900000'; // Unregistered phone

    const sendResult = await authService.sendOtp(phone, 'LOGIN');
    assert.ok(sendResult.challengeId, 'Must return challenge ID even for unknown account');
    assert.equal(smsProvider.sentMessages.length, 0, 'Must NOT dispatch real SMS to unregistered number on LOGIN');

    // If an attacker tries verifying
    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'LOGIN', '123456');
      },
      (err: AppError) => {
        // Since OTP is wrong, it fails verification
        assert.ok(err.statusCode === 401 || err.statusCode === 404);
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 12. REGISTRATION with Existing Account
  // --------------------------------------------------------------------------
  it('should reject REGISTRATION verification if user already exists', async () => {
    const phone = '+919876543210';
    await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });

    const sendResult = await authService.sendOtp(phone, 'REGISTRATION');
    const sentOtp = smsProvider.sentMessages[0].otp;

    await assert.rejects(
      async () => {
        await authService.verifyOtp(sendResult.challengeId, phone, 'REGISTRATION', sentOtp);
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 409);
        assert.equal(err.errorCode, 'USER_ALREADY_EXISTS');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 13. Suspended User
  // --------------------------------------------------------------------------
  it('should block suspended patient accounts from authenticating', async () => {
    const phone = '+919876543210';
    const user = await userRepo.create({ phone, role: 'PATIENT', status: 'SUSPENDED' });

    // Invert to verify check
    const challenge = await otpRepo.create({
      phone,
      otpHash: authService.hashOtp(phone, 'LOGIN', '654321'),
      purpose: 'LOGIN',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
    });

    await assert.rejects(
      async () => {
        await authService.verifyOtp(challenge.id, phone, 'LOGIN', '654321');
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 403);
        assert.equal(err.errorCode, 'ACCOUNT_SUSPENDED');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 14. Valid Access Token
  // --------------------------------------------------------------------------
  it('should create and validate a JWT access token with correct issuer, audience, and claims', async () => {
    const phone = '+919876543210';
    const user = await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });

    const sendResult = await authService.sendOtp(phone, 'LOGIN');
    const sentOtp = smsProvider.sentMessages[0].otp;
    const session = await authService.verifyOtp(sendResult.challengeId, phone, 'LOGIN', sentOtp);

    const tokenPayload = authService.verifyAccessToken(session.tokens.accessToken);
    assert.equal(tokenPayload.sub, user.id);
    assert.equal(tokenPayload.phone, phone);
    assert.equal(tokenPayload.role, 'PATIENT');
    assert.equal(tokenPayload.tokenType, 'access');
  });

  // --------------------------------------------------------------------------
  // 15. Invalid and Expired Access Token
  // --------------------------------------------------------------------------
  it('should reject invalid and expired access tokens', () => {
    // Corrupted token
    assert.throws(
      () => authService.verifyAccessToken('corrupted.token.value'),
      (err: AppError) => err.errorCode === 'INVALID_TOKEN'
    );

    // Expired token
    const expiredToken = jwt.sign(
      { sub: 'user_1', phone: '+919876543210', role: 'PATIENT', status: 'ACTIVE', tokenType: 'access' },
      testConfig.jwtAccessSecret,
      { expiresIn: '-1s', issuer: 'ascas-api', audience: 'ascas-mobile' }
    );

    assert.throws(
      () => authService.verifyAccessToken(expiredToken),
      (err: AppError) => err.errorCode === 'TOKEN_EXPIRED'
    );
  });

  // --------------------------------------------------------------------------
  // 16. Successful Refresh Token Rotation
  // --------------------------------------------------------------------------
  it('should rotate refresh tokens and return new access and refresh token pair', async () => {
    const phone = '+919876543210';
    const user = await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });
    const sendResult = await authService.sendOtp(phone, 'LOGIN');
    const sentOtp = smsProvider.sentMessages[0].otp;
    const session = await authService.verifyOtp(sendResult.challengeId, phone, 'LOGIN', sentOtp);

    const initialRefreshToken = session.tokens.refreshToken;
    const newTokens = await authService.refreshTokens(initialRefreshToken);

    assert.ok(newTokens.accessToken, 'Must return new access token');
    assert.ok(newTokens.refreshToken, 'Must return new refresh token');
    assert.notEqual(newTokens.refreshToken, initialRefreshToken, 'Refresh token must be rotated');

    // Old refresh token must now be revoked
    await assert.rejects(
      async () => {
        await authService.refreshTokens(initialRefreshToken);
      },
      (err: AppError) => err.errorCode === 'REFRESH_TOKEN_REUSE_DETECTED'
    );
  });

  // --------------------------------------------------------------------------
  // 17. Refresh Token Reuse Detection
  // --------------------------------------------------------------------------
  it('should detect reuse of a revoked refresh token and revoke all user sessions', async () => {
    const phone = '+919876543210';
    const user = await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });
    const sendResult = await authService.sendOtp(phone, 'LOGIN');
    const sentOtp = smsProvider.sentMessages[0].otp;
    const session = await authService.verifyOtp(sendResult.challengeId, phone, 'LOGIN', sentOtp);

    const firstToken = session.tokens.refreshToken;
    const secondPair = await authService.refreshTokens(firstToken); // Rotates firstToken

    // Attacker or replayed client attempts to reuse firstToken
    await assert.rejects(
      async () => {
        await authService.refreshTokens(firstToken);
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 401);
        assert.equal(err.errorCode, 'REFRESH_TOKEN_REUSE_DETECTED');
        return true;
      }
    );

    // Because reuse was detected, secondPair.refreshToken must ALSO now be revoked
    await assert.rejects(
      async () => {
        await authService.refreshTokens(secondPair.refreshToken);
      },
      (err: AppError) => {
        assert.equal(err.statusCode, 401);
        assert.equal(err.errorCode, 'REFRESH_TOKEN_REUSE_DETECTED');
        return true;
      }
    );
  });

  // --------------------------------------------------------------------------
  // 18. Logout
  // --------------------------------------------------------------------------
  it('should revoke refresh token upon logout', async () => {
    const phone = '+919876543210';
    await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });
    const sendResult = await authService.sendOtp(phone, 'LOGIN');
    const sentOtp = smsProvider.sentMessages[0].otp;
    const session = await authService.verifyOtp(sendResult.challengeId, phone, 'LOGIN', sentOtp);

    await authService.logout(session.tokens.refreshToken, session.user.id);

    // Attempting refresh after logout must be rejected
    await assert.rejects(
      async () => {
        await authService.refreshTokens(session.tokens.refreshToken);
      },
      (err: AppError) => err.errorCode === 'REFRESH_TOKEN_REUSE_DETECTED'
    );
  });

  it('should reject logout attempt when refresh token belongs to a different user', async () => {
    const phone1 = '+919876543210';
    const phone2 = '+919876543211';
    await userRepo.create({ phone: phone1, role: 'PATIENT', status: 'ACTIVE' });
    await userRepo.create({ phone: phone2, role: 'PATIENT', status: 'ACTIVE' });

    const sendRes1 = await authService.sendOtp(phone1, 'LOGIN');
    const otp1 = smsProvider.sentMessages[smsProvider.sentMessages.length - 1].otp;
    const session1 = await authService.verifyOtp(sendRes1.challengeId, phone1, 'LOGIN', otp1);

    const sendRes2 = await authService.sendOtp(phone2, 'LOGIN');
    const otp2 = smsProvider.sentMessages[smsProvider.sentMessages.length - 1].otp;
    const session2 = await authService.verifyOtp(sendRes2.challengeId, phone2, 'LOGIN', otp2);

    // User 1 attempts to logout using User 2's refresh token
    await assert.rejects(
      async () => {
        await authService.logout(session2.tokens.refreshToken, session1.user.id);
      },
      (err: AppError) => err.statusCode === 403 && err.errorCode === 'FORBIDDEN'
    );

    // User 2's session was NOT revoked and can still refresh
    const refreshed = await authService.refreshTokens(session2.tokens.refreshToken);
    assert.ok(refreshed.accessToken);
  });

  it('should revoke only the matching session when user has multiple active sessions', async () => {
    const phone = '+919876543210';
    await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });

    // Device 1 login
    const send1 = await authService.sendOtp(phone, 'LOGIN');
    const otp1 = smsProvider.sentMessages[smsProvider.sentMessages.length - 1].otp;
    const sessionDevice1 = await authService.verifyOtp(send1.challengeId, phone, 'LOGIN', otp1, 'iPhone 15');

    // Clear cooldown to allow second session creation
    otpRepo.clear();

    // Device 2 login
    const send2 = await authService.sendOtp(phone, 'LOGIN');
    const otp2 = smsProvider.sentMessages[smsProvider.sentMessages.length - 1].otp;
    const sessionDevice2 = await authService.verifyOtp(send2.challengeId, phone, 'LOGIN', otp2, 'Pixel 8');

    // Logout Device 1 only
    await authService.logout(sessionDevice1.tokens.refreshToken, sessionDevice1.user.id);

    // Device 2 refresh MUST succeed (unaffected by Device 1 logout)
    const refreshedDevice2 = await authService.refreshTokens(sessionDevice2.tokens.refreshToken);
    assert.ok(refreshedDevice2.accessToken);
    assert.ok(refreshedDevice2.refreshToken);

    // Device 1 refresh must fail
    await assert.rejects(
      async () => {
        await authService.refreshTokens(sessionDevice1.tokens.refreshToken);
      },
      (err: AppError) => err.errorCode === 'REFRESH_TOKEN_REUSE_DETECTED'
    );
  });

  // --------------------------------------------------------------------------
  // 19. Production Guards and Environment Tests
  // --------------------------------------------------------------------------
  it('should prevent instantiation of mock repositories in production', () => {
    const prevEnv = process.env.NODE_ENV;
    try {
      process.env.NODE_ENV = 'production';
      assert.throws(() => new MockUserRepository(), /cannot be used in production/);
      assert.throws(() => new MockPatientProfileRepository(), /cannot be used in production/);
      assert.throws(() => new MockOtpRepository(), /cannot be used in production/);
      assert.throws(() => new MockRefreshTokenRepository(), /cannot be used in production/);
      assert.throws(() => new DevelopmentSmsProvider(), /cannot be instantiated in production/);
    } finally {
      process.env.NODE_ENV = prevEnv;
    }
  });

  it('should fail application startup in production without injected persistent repositories', () => {
    const prevEnv = process.env.NODE_ENV;
    try {
      process.env.NODE_ENV = 'production';
      assert.throws(() => getDefaultAuthService(), /cannot be used in production/);
      assert.throws(() => createAuthRouter(), /cannot be used in production/);
    } finally {
      process.env.NODE_ENV = prevEnv;
    }
  });

  it('should successfully initialize auth router in development or test environment', () => {
    const router = createAuthRouter();
    assert.ok(router);
  });

  // --------------------------------------------------------------------------
  // 20. Concurrent Refresh Requests
  // --------------------------------------------------------------------------
  it('should safely handle concurrent refresh requests, ensuring only one rotation succeeds', async () => {
    const phone = '+919876543210';
    await userRepo.create({ phone, role: 'PATIENT', status: 'ACTIVE' });
    const sendResult = await authService.sendOtp(phone, 'LOGIN');
    const sentOtp = smsProvider.sentMessages[0].otp;
    const session = await authService.verifyOtp(sendResult.challengeId, phone, 'LOGIN', sentOtp);

    const tokenToRefresh = session.tokens.refreshToken;

    // Fire two concurrent refresh requests
    const results = await Promise.allSettled([
      authService.refreshTokens(tokenToRefresh),
      authService.refreshTokens(tokenToRefresh),
    ]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    assert.equal(fulfilled.length, 1, 'Exactly one concurrent refresh request must succeed');
    assert.equal(rejected.length, 1, 'Concurrent replay request must be rejected');
  });
});
