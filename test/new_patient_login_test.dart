import 'package:app/features/auth/presentation/forgot_password/forgot_password_screen.dart';
import 'package:app/features/auth/presentation/forgot_password/forgot_password_otp_screen.dart';
import 'package:app/features/auth/presentation/forgot_password/reset_password_screen.dart';
import 'package:app/features/auth/presentation/app_security_screen.dart';
import 'package:app/features/auth/presentation/consent_privacy_screen.dart';
import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/features/auth/presentation/new_patient/mobile_registration_screen.dart';
import 'package:app/features/auth/presentation/new_patient/new_patient_otp_screen.dart';
import 'package:app/features/auth/presentation/patient_type_screen.dart';
import 'package:app/features/auth/presentation/new_patient/profile_confirmation_screen.dart';
import 'package:app/features/auth/data/account_identity_service.dart';
import 'package:app/features/dashboard/presentation/widgets/patient_profile_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('new patient registration continues through mobile OTP', (
    WidgetTester tester,
  ) async {
    final apiClient = ApiClient.instance.dio;
    final otpSendStub = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith('/auth/otp/send')) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'challengeId': 'test-challenge',
                  'retryAfterSeconds': 30,
                },
              },
            ),
          );
        } else {
          handler.next(options);
        }
      },
    );
    apiClient.interceptors.add(otpSendStub);
    addTearDown(() => apiClient.interceptors.remove(otpSendStub));

    await tester.pumpWidget(_localizedApp(const PatientTypeScreen()));

    await tester.tap(find.text('New Patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(MobileRegistrationScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(NewPatientOtpScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new patient email carries through consent to app security', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        const ProfileConfirmationScreen(
          fullName: 'Patient Name',
          dateOfBirth: '02/04/1994',
          mobileNumber: '9876543210',
          email: 'patient@example.com',
          preferredLanguage: 'English',
          gender: 'Female',
        ),
      ),
    );
    final confirmButton = find.text('Yes, this is me');
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentPrivacyScreen), findsOneWidget);

    final consent = find.byType(Checkbox);
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pump();
    final continueButton = find.text('Accept and continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppSecurityScreen>(find.byType(AppSecurityScreen)).email,
      'patient@example.com',
    );
  });

  testWidgets('forgot password opens mobile and email recovery from login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_loginApp());

    expect(find.text('Google'), findsNothing);
    expect(find.text('Apple'), findsNothing);
    expect(find.textContaining('Email OTP Testing'), findsNothing);
    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forgot-password-mobile-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forgot-password-email-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forgot-password-send-otp')),
      findsOneWidget,
    );
  });

  testWidgets(
    'email OTP recovery validates contacts, resends, and routes after verification',
    (WidgetTester tester) async {
      final requestedEmails = <String>[];
      final verifiedOtps = <String>[];
      Future<String> requestOtp(String email) async {
        requestedEmails.add(email);
        return 'OTP sent successfully.';
      }

      Future<String> verifyOtp(String email, String otp) async {
        verifiedOtps.add(otp);
        if (otp == '000000') {
          throw Exception('Incorrect OTP. Please try again.');
        }
        if (otp == '111111') {
          throw Exception('OTP has expired. Please request a new OTP.');
        }
        return 'Email verified successfully.';
      }

      await tester.pumpWidget(
        _localizedApp(
          ForgotPasswordScreen(requestOtp: requestOtp, verifyOtp: verifyOtp),
        ),
      );
      final mobileField = find.byKey(
        const ValueKey('forgot-password-mobile-field'),
      );
      final emailField = find.byKey(
        const ValueKey('forgot-password-email-field'),
      );
      final sendOtp = find.byKey(const ValueKey('forgot-password-send-otp'));
      expect(tester.widget<ElevatedButton>(sendOtp).onPressed, isNull);
      await tester.enterText(mobileField, '1234');
      await tester.pump();
      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(sendOtp).onPressed, isNull);

      await tester.enterText(mobileField, '9876543210');
      await tester.enterText(emailField, 'not-an-email');
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(sendOtp).onPressed, isNull);
      await tester.enterText(emailField, 'patient@example.com');
      await tester.pump();
      await tester.ensureVisible(sendOtp);
      await tester.tap(sendOtp);
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordOtpScreen), findsOneWidget);
      expect(find.text('patient@example.com'), findsOneWidget);
      expect(find.text('Enter the six-digit code sent to:'), findsOneWidget);
      expect(find.text('Registered mobile number'), findsNothing);
      expect(find.text('+91 9876543210'), findsNothing);
      expect(find.text('Resend OTP in 30s'), findsOneWidget);
      expect(requestedEmails, ['patient@example.com']);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.text('Resend OTP'), findsOneWidget);
      await tester.ensureVisible(find.text('Resend OTP'));
      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();
      expect(requestedEmails, ['patient@example.com', 'patient@example.com']);
      expect(find.text('Resend OTP in 30s'), findsOneWidget);

      final firstOtpField = find.byKey(const ValueKey('forgot-password-otp-0'));
      final verifyButton = find.text('Verify OTP');
      await tester.enterText(firstOtpField, '000000');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(find.text('Incorrect OTP. Please try again.'), findsOneWidget);

      await tester.enterText(firstOtpField, '111111');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(
        find.text('OTP has expired. Please request a new OTP.'),
        findsOneWidget,
      );

      await tester.enterText(firstOtpField, '123456');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordOtpScreen), findsNothing);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(verifiedOtps, ['000000', '111111', '123456']);
      expect(find.textContaining('Email OTP verification alone'), findsNothing);
    },
  );

  testWidgets(
    'reset password validates input and remains blocked without backend authorization',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _localizedApp(
          const ResetPasswordScreen(
            registeredMobile: '9876543210',
            registeredEmail: 'patient@example.com',
          ),
        ),
      );
      final resetButton = find.byKey(const ValueKey('reset-password-submit'));
      await tester.enterText(
        find.byKey(const ValueKey('reset-new-password-field')),
        'short',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password-field')),
        'short',
      );
      await tester.pump();
      expect(find.text('Weak'), findsOneWidget);
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Password must contain at least 8 characters.'),
        findsNWidgets(2),
      );
      await tester.pump(const Duration(seconds: 5));

      await tester.enterText(
        find.byKey(const ValueKey('reset-new-password-field')),
        'NewPassword123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password-field')),
        'DifferentPassword123',
      );
      await tester.pump();
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsWidgets);
      await tester.pump(const Duration(seconds: 5));

      await tester.enterText(
        find.byKey(const ValueKey('reset-new-password-field')),
        'NewPassword123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password-field')),
        'NewPassword123',
      );
      await tester.pump();
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('We could not update your password right now'),
        findsOneWidget,
      );
    },
  );

  testWidgets('password update failure remains on reset screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        ResetPasswordScreen(
          registeredMobile: '9876543210',
          registeredEmail: 'patient@example.com',
          resetAuthorizationToken: 'single-use-token',
          resetPassword: (_, _) async {
            throw Exception('Backend rejected password update.');
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-new-password-field')),
      'SecurePass123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-password-field')),
      'SecurePass123!',
    );
    await tester.pump();
    final resetButton = find.byKey(const ValueKey('reset-password-submit'));
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.text('Backend rejected password update.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('successful password update clears recovery stack to Login', (
    WidgetTester tester,
  ) async {
    String? submittedToken;
    String? submittedPassword;
    await tester.pumpWidget(
      _localizedApp(
        ResetPasswordScreen(
          registeredMobile: '9876543210',
          registeredEmail: 'patient@example.com',
          resetAuthorizationToken: 'single-use-token',
          resetPassword: (token, password) async {
            submittedToken = token;
            submittedPassword = password;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-new-password-field')),
      'SecurePass123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-password-field')),
      'SecurePass123!',
    );
    await tester.pump();
    final resetButton = find.byKey(const ValueKey('reset-password-submit'));
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(submittedToken, 'single-use-token');
    expect(submittedPassword, 'SecurePass123!');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(
      find.textContaining('Your password has been updated successfully'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('changed email is saved only after OTP verification', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = AccountIdentityService();
    final identity = await accounts.createOrGetNewPatient(
      mobileNumber: '9876543210',
      fullName: 'Patient Name',
      dateOfBirth: '02/04/1994',
      preferredLanguage: 'English',
      email: 'old@example.com',
    );
    final requestedEmails = <String>[];
    await tester.pumpWidget(
      _personalDetailsLauncher(
        identity: identity,
        requestOtp: (email) async {
          requestedEmails.add(email);
          return 'OTP sent.';
        },
        verifyOtp: (email, otp) async {
          if (otp == '000000') throw Exception('Incorrect OTP');
          if (otp == '111111') {
            throw Exception('OTP has expired. Please request a new OTP.');
          }
          return 'Verified.';
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-personal-details')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('personal-details-update')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-name')),
      'Updated Patient',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-email')),
      'new@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('personal-details-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('change-email-verify-otp')),
      findsOneWidget,
    );
    expect(
      (await accounts.accountForId(identity.accountId))?.email,
      'old@example.com',
    );

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('change-email-otp-$i')), '0');
    }
    await tester.tap(find.byKey(const ValueKey('change-email-verify-otp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Incorrect OTP'), findsOneWidget);
    expect(
      (await accounts.accountForId(identity.accountId))?.email,
      'old@example.com',
    );

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('change-email-otp-$i')), '1');
    }
    await tester.tap(find.byKey(const ValueKey('change-email-verify-otp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('OTP has expired. Please request a new OTP.'),
      findsOneWidget,
    );
    expect(
      (await accounts.accountForId(identity.accountId))?.email,
      'old@example.com',
    );

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('change-email-otp-$i')), '2');
    }
    await tester.tap(find.byKey(const ValueKey('change-email-verify-otp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final saved = await accounts.accountForId(identity.accountId);
    expect(saved?.fullName, 'Updated Patient');
    expect(saved?.email, 'new@example.com');
    expect(requestedEmails, ['new@example.com']);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('new@example.com'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

Widget _personalDetailsLauncher({
  required AccountIdentity identity,
  required Future<String> Function(String email) requestOtp,
  required Future<String> Function(String email, String otp) verifyOtp,
}) => _localizedApp(
  Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('open-personal-details'),
          onPressed: () => Navigator.push<PatientProfileData>(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalDetailsScreen(
                name: identity.fullName,
                mobile: identity.mobileNumber,
                email: identity.email,
                dateOfBirth: identity.dateOfBirth,
                language: identity.preferredLanguage,
                accountId: identity.accountId,
                requestOtp: requestOtp,
                verifyOtp: verifyOtp,
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Widget _loginApp() => _localizedApp(const LoginScreen());

Widget _localizedApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
