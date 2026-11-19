import 'package:app/features/auth/data/account_identity_service.dart';
import 'package:app/features/dashboard/presentation/widgets/patient_profile_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('read-only details can be edited, cancelled, and saved', (
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
    var requestedOtp = false;
    await tester.pumpWidget(
      _localizedApp(
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
                      requestOtp: (email) async {
                        requestedOtp = true;
                        return 'OTP sent.';
                      },
                      verifyOtp: (email, otp) async => 'Verified.',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-personal-details')));
    await tester.pumpAndSettle();
    expect(find.text('Patient Name'), findsOneWidget);
    expect(find.text('02/04/1994'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('old@example.com'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Date of Birth'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const ValueKey('personal-details-update')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('personal-details-name')),
          )
          .readOnly,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('personal-details-mobile')),
          )
          .readOnly,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('personal-details-email')),
          )
          .readOnly,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('personal-details-date-of-birth')),
          )
          .onTap,
      isNotNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-name')),
      'Discarded Name',
    );
    await tester.tap(find.byKey(const ValueKey('personal-details-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Patient Name'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('personal-details-update')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-name')),
      'Updated Patient',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-email')),
      'not-an-email',
    );
    await tester.tap(find.byKey(const ValueKey('personal-details-save')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email address'), findsOneWidget);
    expect(requestedOtp, isFalse);
    expect(
      (await accounts.accountForId(identity.accountId))?.fullName,
      'Patient Name',
    );

    await tester.enterText(
      find.byKey(const ValueKey('personal-details-email')),
      'old@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('personal-details-save')));
    await tester.pumpAndSettle();

    final saved = await accounts.accountForId(identity.accountId);
    expect(requestedOtp, isFalse);
    expect(saved?.fullName, 'Updated Patient');
    expect(saved?.email, 'old@example.com');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Updated Patient'), findsOneWidget);
  });
}

Widget _localizedApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
