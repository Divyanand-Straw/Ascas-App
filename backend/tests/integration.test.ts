import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'http';
import app from '../src/app';
import { getDefaultAuthService } from '../src/modules/auth/auth.routes';

describe('ASCAS Phase 1 Backend API Integration Tests', () => {
  let server: http.Server;
  let baseUrl: string;

  before(async () => {
    await new Promise<void>((resolve) => {
      server = app.listen(0, () => {
        const address = server.address() as { port: number };
        baseUrl = `http://127.0.0.1:${address.port}/api/v1/auth`;
        resolve();
      });
    });
    assert.ok(baseUrl);
  });

  after(async () => {
    await new Promise<void>((resolve) => {
      server.close(() => resolve());
    });
  });

  it('should reject invalid verification, unauthenticated access, and invalid refresh token', async () => {
    // 1. Send OTP for REGISTRATION
    const sendRes = await fetch(`${baseUrl}/otp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: '+919876543210',
        purpose: 'REGISTRATION',
      }),
    });

    assert.equal(sendRes.status, 200);
    const sendData = (await sendRes.json()) as any;
    assert.equal(sendData.success, true);
    assert.ok(sendData.data.challengeId);

    const challengeId = sendData.data.challengeId;

    // 2. Extract OTP from verify (test invalid OTP first)
    const invalidVerifyRes = await fetch(`${baseUrl}/otp/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        challengeId,
        phone: '+919876543210',
        purpose: 'REGISTRATION',
        otp: '000000',
      }),
    });

    assert.equal(invalidVerifyRes.status, 401);
    const invalidData = (await invalidVerifyRes.json()) as any;
    assert.equal(invalidData.errorCode, 'INVALID_OTP');

    // 3. Test GET /me without auth header -> 401
    const unauthMe = await fetch(`${baseUrl}/me`);
    assert.equal(unauthMe.status, 401);

    // 4. Test Refresh with invalid token -> 401
    const invalidRefresh = await fetch(`${baseUrl}/token/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: 'invalid_dummy_token' }),
    });
    assert.equal(invalidRefresh.status, 401);
  });

  it('should enforce authentication and schema validation on logout endpoint', async () => {
    // 1. Logout without Bearer token -> 401
    const noAuthLogout = await fetch(`${baseUrl}/logout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: 'some_token' }),
    });
    assert.equal(noAuthLogout.status, 401);
    const noAuthData = (await noAuthLogout.json()) as any;
    assert.equal(noAuthData.errorCode, 'UNAUTHORIZED');

    // To test empty body validation, we obtain a valid token via registration
    const defaultService = getDefaultAuthService();
    const phone = '+919123456789';

    const sendRes = await fetch(`${baseUrl}/otp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone,
        purpose: 'REGISTRATION',
      }),
    });
    assert.equal(sendRes.status, 200);
    const sendData = (await sendRes.json()) as any;

    const messages = (defaultService as any).smsProvider.sentMessages;
    const otp = messages[messages.length - 1].otp;

    const verifyRes = await fetch(`${baseUrl}/otp/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        challengeId: sendData.data.challengeId,
        phone,
        purpose: 'REGISTRATION',
        otp,
      }),
    });
    assert.equal(verifyRes.status, 200);
    const verifyData = (await verifyRes.json()) as any;
    const accessToken = verifyData.data.tokens.accessToken;

    // 2. Logout with empty body -> 400 Validation Error
    const emptyBodyLogout = await fetch(`${baseUrl}/logout`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({}),
    });
    assert.equal(emptyBodyLogout.status, 400);
    const emptyBodyData = (await emptyBodyLogout.json()) as any;
    assert.equal(emptyBodyData.errorCode, 'VALIDATION_ERROR');
  });

  it('should execute complete logout workflow, block cross-user token revocation, and prevent reuse', async () => {
    const defaultService = getDefaultAuthService();

    // 1. Register User A
    const phoneA = '+919999900001';
    const sendResA = await fetch(`${baseUrl}/otp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: phoneA, purpose: 'REGISTRATION' }),
    });
    assert.equal(sendResA.status, 200);
    const sendDataA = (await sendResA.json()) as any;
    const messagesA = (defaultService as any).smsProvider.sentMessages;
    const otpA = messagesA[messagesA.length - 1].otp;

    const verifyResA = await fetch(`${baseUrl}/otp/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        challengeId: sendDataA.data.challengeId,
        phone: phoneA,
        purpose: 'REGISTRATION',
        otp: otpA,
      }),
    });
    assert.equal(verifyResA.status, 200);
    const sessionA = ((await verifyResA.json()) as any).data;

    // 2. Register User B
    const phoneB = '+919999900002';
    const sendResB = await fetch(`${baseUrl}/otp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: phoneB, purpose: 'REGISTRATION' }),
    });
    assert.equal(sendResB.status, 200);
    const sendDataB = (await sendResB.json()) as any;
    const messagesB = (defaultService as any).smsProvider.sentMessages;
    const otpB = messagesB[messagesB.length - 1].otp;

    const verifyResB = await fetch(`${baseUrl}/otp/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        challengeId: sendDataB.data.challengeId,
        phone: phoneB,
        purpose: 'REGISTRATION',
        otp: otpB,
      }),
    });
    assert.equal(verifyResB.status, 200);
    const sessionB = ((await verifyResB.json()) as any).data;

    // 3. User A attempts to revoke User B's refresh token -> 403 Forbidden
    const crossLogoutRes = await fetch(`${baseUrl}/logout`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${sessionA.tokens.accessToken}`,
      },
      body: JSON.stringify({ refreshToken: sessionB.tokens.refreshToken }),
    });
    assert.equal(crossLogoutRes.status, 403);
    const crossData = (await crossLogoutRes.json()) as any;
    assert.equal(crossData.errorCode, 'FORBIDDEN');

    // User B's token remains valid and can refresh
    const refreshBRes = await fetch(`${baseUrl}/token/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: sessionB.tokens.refreshToken }),
    });
    assert.equal(refreshBRes.status, 200);

    // 4. User A logs out with valid own token -> 200 OK
    const logoutARes = await fetch(`${baseUrl}/logout`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${sessionA.tokens.accessToken}`,
      },
      body: JSON.stringify({ refreshToken: sessionA.tokens.refreshToken }),
    });
    assert.equal(logoutARes.status, 200);
    const logoutAData = (await logoutARes.json()) as any;
    assert.equal(logoutAData.success, true);
    assert.equal(logoutAData.message, 'Logged out successfully');

    // 5. User A's revoked refresh token CANNOT be refreshed -> 401
    const revokedRefreshRes = await fetch(`${baseUrl}/token/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: sessionA.tokens.refreshToken }),
    });
    assert.equal(revokedRefreshRes.status, 401);
  });
});
