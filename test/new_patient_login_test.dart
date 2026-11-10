import 'package:app/features/auth/presentation/forgot_password/forgot_password_screen.dart';
import 'package:app/features/auth/presentation/forgot_password/forgot_password_otp_screen.dart';
import 'package:app/features/auth/presentation/forgot_password/reset_password_screen.dart';
import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('forgot password flows through OTP and returns to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_loginApp());

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.textContaining('No backend'), findsNothing);
    expect(find.textContaining('123456'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-mobile-field')),
      '9123456780',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      'patient@example.com',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('forgot-password-continue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forgot-password-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordOtpScreen), findsOneWidget);
    expect(find.textContaining('Preview only'), findsNothing);

    for (var index = 0; index < 6; index++) {
      await tester.enterText(
        find.byKey(ValueKey('forgot-password-otp-$index')),
        '$index',
      );
    }

    await tester.ensureVisible(find.text('Verify & Continue'));
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('reset-new-password-field')),
      'NewPassword123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-password-field')),
      'NewPassword123',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('reset-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('reset-password-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Password updated'), findsOneWidget);
    expect(
      find.text(
        'This password change is not saved until account services are connected. You can return to login.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
  });
}

Widget _loginApp() => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const LoginScreen(),
);
