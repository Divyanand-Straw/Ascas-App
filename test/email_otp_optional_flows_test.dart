import 'package:app/features/auth/data/models/auth_models.dart';
import 'package:app/features/auth/presentation/developer_email_otp_testing_screen.dart';
import 'package:app/features/auth/presentation/email_password_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new patient can optionally verify email and set a password', (
    tester,
  ) async {
    final requestedEmails = <String>[];
    final verified = <String>[];
    final passwords = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: EmailPasswordSetupScreen(
          initialEmail: ' New.Patient@Example.COM ',
          requestOtp: (email) async {
            requestedEmails.add(email);
            return const SendEmailOtpResponse(
              challengeId: 'activation-challenge',
              expiresInSeconds: 300,
              retryAfterSeconds: 30,
            );
          },
          verifyOtp: (challengeId, email, otp) async {
            verified.add('$challengeId|$email|$otp');
            return const EmailActivationOtpVerificationResponse();
          },
          setupPassword: (password) async => passwords.add(password),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('email-password-setup-send')));
    await tester.pumpAndSettle();
    expect(requestedEmails, ['new.patient@example.com']);
    expect(find.text('Resend in 30s'), findsOneWidget);

    for (var index = 0; index < 6; index++) {
      await tester.enterText(
        find.byKey(ValueKey('email-password-setup-otp-$index')),
        '${index + 1}',
      );
    }
    await tester.tap(find.byKey(const ValueKey('email-password-setup-verify')));
    await tester.pumpAndSettle();
    expect(verified, ['activation-challenge|new.patient@example.com|123456']);

    await tester.enterText(
      find.byKey(const ValueKey('email-password-setup-password')),
      'NewPatientSecurePass123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('email-password-setup-confirm')),
      'NewPatientSecurePass123',
    );
    await tester.tap(find.byKey(const ValueKey('email-password-setup-submit')));
    await tester.pumpAndSettle();

    expect(passwords, ['NewPatientSecurePass123']);
    expect(
      find.byKey(const ValueKey('email-password-setup-success')),
      findsOneWidget,
    );
  });

  testWidgets(
    'staging developer tester verifies without account side effects',
    (tester) async {
      final requests = <String>[];
      final verifications = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: DeveloperEmailOtpTestingScreen(
            requestOtp: (email) async {
              requests.add(email);
              return const SendEmailOtpResponse(
                challengeId: 'reset-challenge',
                expiresInSeconds: 300,
                retryAfterSeconds: 30,
              );
            },
            verifyOtp: (challengeId, email, otp) async {
              verifications.add('$challengeId|$email|$otp');
              return const DeveloperEmailTestOtpVerificationResponse();
            },
            currentTime: () => tester.binding.clock.now(),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('developer-email-otp-eligibility')),
        findsOneWidget,
      );
      expect(find.textContaining('without a patient account'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('developer-email-otp-email')),
        ' Test.User@Example.COM ',
      );
      await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
      await tester.pump();
      await tester.pump();
      expect(requests, ['test.user@example.com']);
      expect(
        find.textContaining('Brevo accepted the send request.'),
        findsOneWidget,
      );
      expect(find.text('This code expires in 5m.'), findsOneWidget);
      expect(find.text('Resend in 30s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('Resend in 1s'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('developer-email-otp-resend')),
            )
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Resend OTP'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('developer-email-otp-resend')),
      );
      await tester.pump();
      await tester.pump();
      expect(requests, ['test.user@example.com', 'test.user@example.com']);
      expect(find.text('Resend in 30s'), findsOneWidget);

      for (var index = 0; index < 6; index++) {
        await tester.enterText(
          find.byKey(ValueKey('developer-email-otp-code-$index')),
          '9',
        );
      }
      await tester.tap(
        find.byKey(const ValueKey('developer-email-otp-verify')),
      );
      await tester.pumpAndSettle();

      expect(verifications, ['reset-challenge|test.user@example.com|999999']);
      expect(
        find.byKey(const ValueKey('developer-email-otp-success')),
        findsOneWidget,
      );
      expect(
        find.text('This code has been verified and cannot be reused.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('developer tester displays OTP expiry as remaining time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeveloperEmailOtpTestingScreen(
          requestOtp: (email) async => const SendEmailOtpResponse(
            challengeId: 'expiry-challenge',
            expiresInSeconds: 300,
            retryAfterSeconds: 30,
          ),
          verifyOtp: (challengeId, email, otp) async => throw ApiError(
            statusCode: 401,
            errorCode: 'INVALID_EMAIL_OTP',
            message: 'Verification code is invalid or has expired.',
          ),
          currentTime: () => tester.binding.clock.now(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('developer-email-otp-email')),
      'test.user@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
    await tester.pump();
    await tester.pump();
    expect(find.text('This code expires in 5m.'), findsOneWidget);

    await tester.pump(const Duration(minutes: 4));
    expect(find.textContaining('This code expires in'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(
      find.text('This code has expired. Request a new OTP.'),
      findsOneWidget,
    );
    for (var index = 0; index < 6; index++) {
      await tester.enterText(
        find.byKey(ValueKey('developer-email-otp-code-$index')),
        '1',
      );
    }
    await tester.tap(find.byKey(const ValueKey('developer-email-otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.text('Verification code is invalid or has expired.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'developer tester separates an hourly lockout from the normal resend cooldown',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeveloperEmailOtpTestingScreen(
            requestOtp: (email) async => throw ApiError(
              statusCode: 429,
              errorCode: 'EMAIL_OTP_RATE_LIMITED',
              message:
                  'Too many email test codes were requested. Try again later.',
              details: {'scope': 'email', 'retryAfterSeconds': 2050},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('developer-email-otp-email')),
        'test.user@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Hourly limit: 34m 10s'), findsOneWidget);
      expect(
        find.textContaining(
          'separate from the normal 30-second resend cooldown',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('developer-email-otp-send')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('developer tester preserves a longer Brevo Retry-After interval', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeveloperEmailOtpTestingScreen(
          requestOtp: (email) async => throw ApiError(
            statusCode: 502,
            errorCode: 'BREVO_RATE_LIMITED',
            message: 'Brevo rate-limited transactional email delivery.',
            details: {
              'retryAfterSeconds': 120,
              'providerRetryAfterSeconds': 120,
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('developer-email-otp-email')),
      'test.user@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Provider wait: 2m'), findsOneWidget);
    expect(
      find.textContaining(
        'provider limit is separate from the normal 30-second resend cooldown',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'developer tester waits for the server resend delay after failure',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DeveloperEmailOtpTestingScreen(
            currentTime: () => tester.binding.clock.now(),
            requestOtp: (email) async {
              requests++;
              if (requests == 1) {
                throw ApiError(
                  statusCode: 502,
                  errorCode: 'BREVO_AUTHENTICATION_FAILED',
                  message: 'Brevo rejected the API credentials (HTTP 401).',
                  details: {'retryAfterSeconds': 30},
                );
              }
              return const SendEmailOtpResponse(
                challengeId: 'retry-challenge',
                expiresInSeconds: 300,
                retryAfterSeconds: 30,
              );
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('developer-email-otp-email')),
        'test.user@example.com',
      );

      await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Brevo rejected the API credentials (HTTP 401).'),
        findsOneWidget,
      );
      expect(find.text('Try again in 30s'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('developer-email-otp-send')),
            )
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.text('Send Test OTP'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
      await tester.pump();
      await tester.pump();
      expect(requests, 2);
      expect(find.text('Resend in 30s'), findsOneWidget);
    },
  );

  testWidgets(
    'developer tester validates email and displays network failures safely',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DeveloperEmailOtpTestingScreen(
            requestOtp: (email) async {
              requests++;
              throw ApiError(
                statusCode: 503,
                errorCode: 'NETWORK_UNAVAILABLE',
                message: 'Unable to reach the server. Please verify your connection.',
              );
            },
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('developer-email-otp-email')),
        'invalid-address',
      );
      await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(find.text('Enter a valid test email address.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('developer-email-otp-email')),
        'test.user@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('developer-email-otp-send')));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.text('Unable to reach the server. Please verify your connection.'),
        findsOneWidget,
      );
    },
  );
}
