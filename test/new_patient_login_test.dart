import 'package:app/features/auth/data/account_identity_service.dart';
import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('new patient can sign in to their saved identity', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final identity = await AccountIdentityService().createOrGetNewPatient(
      mobileNumber: '9876543210',
      fullName: 'New Patient',
      dateOfBirth: '02/04/1994',
      preferredLanguage: 'English',
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
    expect(dashboard.patientName, 'New Patient');
    expect(dashboard.patientId, identity.patientId);
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
