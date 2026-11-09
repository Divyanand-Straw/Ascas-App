import 'package:app/features/auth/data/account_identity_service.dart';
import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('existing patient signs in with the saved patient identity', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = AccountIdentityService();
    final registered = await accounts.createOrGetNewPatient(
      mobileNumber: '9123456780',
      fullName: 'Existing Test Patient',
      dateOfBirth: '14/08/1992',
      preferredLanguage: 'English',
    );
    final identity = await AccountIdentityService().resolveExistingPatient(
      mobileNumber: registered.mobileNumber,
      patientId: registered.patientId,
      dateOfBirth: '14/08/1992',
    );

    await tester.pumpWidget(_loginApp());
    await tester.enterText(
      find.byKey(const ValueKey('login-mobile-field')),
      identity.mobileNumber,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-otp-field')),
      '123456',
    );
    await tester.ensureVisible(find.byType(ElevatedButton).first);
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dashboard = tester.widget<DashboardScreen>(
      find.byType(DashboardScreen),
    );
    expect(dashboard.patientName, 'Existing Test Patient');
    expect(dashboard.patientId, registered.patientId);
    expect(dashboard.accountId, identity.accountId);
    expect(tester.takeException(), isNull);
  });
}

Widget _loginApp() => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const LoginScreen(),
);
