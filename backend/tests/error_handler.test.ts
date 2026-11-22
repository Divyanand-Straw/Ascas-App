import assert from 'node:assert/strict';
import { it } from 'node:test';
import type { NextFunction, Request, Response } from 'express';
import { errorHandler } from '../src/middleware/errorHandler';
import { AppError } from '../src/utils/errors';

it('preserves a sanitized Brevo provider 401 in the API response', () => {
  let responseStatus = 0;
  let responseBody: unknown;
  const response = {
    status(status: number) {
      responseStatus = status;
      return this;
    },
    json(body: unknown) {
      responseBody = body;
      return this;
    },
  } as unknown as Response;

  errorHandler(
    new AppError(
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
    ),
    {} as Request,
    response,
    (() => undefined) as NextFunction
  );

  assert.equal(responseStatus, 401);
  assert.deepEqual(responseBody, {
    success: false,
    errorCode: 'BREVO_AUTHENTICATION_FAILED',
    message: 'Brevo rejected the API request (HTTP 401): Invalid API key.',
    details: {
      provider: 'Brevo',
      source: 'email_provider',
      httpStatus: 401,
      providerCode: 'unauthorized',
      providerMessage: 'Invalid API key.',
    },
  });
});

it('does not log request credentials or exception messages in production', () => {
  const previousEnv = process.env.NODE_ENV;
  const originalConsoleError = console.error;
  const logged: string[] = [];
  let responseStatus = 0;
  let responseBody: unknown;

  const response = {
    status(status: number) {
      responseStatus = status;
      return this;
    },
    json(body: unknown) {
      responseBody = body;
      return this;
    },
  } as unknown as Response;
  const request = {
    body: {
      password: 'synthetic-password-value',
      refreshToken: 'synthetic-refresh-token',
      otp: 'synthetic-email-otp',
      resetGrant: 'synthetic-reset-grant',
    },
    headers: {
      authorization: 'Bearer synthetic-access-token',
    },
  } as unknown as Request;

  try {
    process.env.NODE_ENV = 'production';
    console.error = (...args: unknown[]) => logged.push(args.join(' '));
    errorHandler(
      new Error(
        'password=synthetic-password-value token=synthetic-access-token otp=synthetic-email-otp resetGrant=synthetic-reset-grant'
      ),
      request,
      response,
      (() => undefined) as NextFunction
    );

    const logOutput = logged.join(' ');
    assert.equal(responseStatus, 500);
    assert.equal(logOutput.includes('synthetic-password-value'), false);
    assert.equal(logOutput.includes('synthetic-access-token'), false);
    assert.equal(logOutput.includes('synthetic-refresh-token'), false);
    assert.equal(logOutput.includes('synthetic-email-otp'), false);
    assert.equal(logOutput.includes('synthetic-reset-grant'), false);
    assert.match(logOutput, /Error/);
    assert.ok(
      typeof responseBody === 'object' &&
        responseBody !== null &&
        'message' in responseBody
    );
    assert.equal(
      (responseBody as { message: string }).message,
      'Internal server error'
    );
  } finally {
    console.error = originalConsoleError;
    if (previousEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousEnv;
  }
});

it('redacts unexpected errors in APP_ENV staging even when NODE_ENV is development', () => {
  const previousAppEnv = process.env.APP_ENV;
  const previousNodeEnv = process.env.NODE_ENV;
  const originalConsoleError = console.error;
  const logged: string[] = [];
  let responseBody: unknown;
  const response = {
    status() {
      return this;
    },
    json(body: unknown) {
      responseBody = body;
      return this;
    },
  } as unknown as Response;

  try {
    process.env.APP_ENV = 'staging';
    process.env.NODE_ENV = 'development';
    console.error = (...args: unknown[]) => logged.push(args.join(' '));
    errorHandler(
      new Error('synthetic-email-otp synthetic-api-secret'),
      { body: { otp: 'synthetic-email-otp' } } as unknown as Request,
      response,
      (() => undefined) as NextFunction
    );

    assert.equal(
      logged.join(' ').includes('synthetic-email-otp'),
      false
    );
    assert.equal(logged.join(' ').includes('synthetic-api-secret'), false);
    assert.equal(
      (responseBody as { message: string }).message,
      'Internal server error'
    );
  } finally {
    console.error = originalConsoleError;
    if (previousAppEnv === undefined) delete process.env.APP_ENV;
    else process.env.APP_ENV = previousAppEnv;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
  }
});

it('maps PostgreSQL schema errors to a sanitized response and logs only SQLSTATE', () => {
  const previousAppEnv = process.env.APP_ENV;
  const previousNodeEnv = process.env.NODE_ENV;
  const originalConsoleError = console.error;
  const logged: string[] = [];
  let responseStatus = 0;
  let responseBody: unknown;
  const response = {
    status(status: number) {
      responseStatus = status;
      return this;
    },
    json(body: unknown) {
      responseBody = body;
      return this;
    },
  } as unknown as Response;
  const phone = '+919876543210';
  const otp = '123456';
  const databaseError = Object.assign(
    new Error(`phone_verified_at missing for ${phone}; otp=${otp}`),
    { code: '42703' }
  );

  try {
    process.env.APP_ENV = 'staging';
    process.env.NODE_ENV = 'development';
    console.error = (...args: unknown[]) => logged.push(args.join(' '));
    errorHandler(
      databaseError,
      {
        body: { phone, otp },
        headers: {},
      } as unknown as Request,
      response,
      (() => undefined) as NextFunction
    );

    assert.equal(responseStatus, 503);
    assert.deepEqual(responseBody, {
      success: false,
      errorCode: 'DATABASE_SCHEMA_OUT_OF_DATE',
      message: 'The request could not be completed. Please try again later.',
    });
    const logOutput = logged.join(' ');
    assert.match(logOutput, /SQLSTATE 42703/);
    assert.equal(logOutput.includes(phone), false);
    assert.equal(logOutput.includes(otp), false);
    assert.equal(logOutput.includes('phone_verified_at missing'), false);
  } finally {
    console.error = originalConsoleError;
    if (previousAppEnv === undefined) delete process.env.APP_ENV;
    else process.env.APP_ENV = previousAppEnv;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
  }
});
