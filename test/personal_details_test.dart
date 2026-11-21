import 'package:app/features/auth/data/account_identity_service.dart';
import 'package:app/features/auth/data/models/auth_models.dart'
    hide PatientProfileData;
import 'package:app/features/dashboard/presentation/widgets/dashboard_home_content.dart';
import 'package:app/features/dashboard/presentation/widgets/patient_profile_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home shows a readable Patient ID instead of the birthday', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const dateOfBirth = '1994-06-15T00:00:00.000Z';

    await tester.pumpWidget(
      _localizedApp(
        Scaffold(
          body: DashboardHomeContent(
            patientName: 'Patient Name',
            dateOfBirth: dateOfBirth,
            patientId: 'TS-AB123',
            patientState: DashboardPatientState.newPatient,
            onNavigate: (_) {},
            isLinkedPartner: true,
            partnerPermissions: const {'Patient profile information': true},
          ),
        ),
      ),
    );
    expect(find.text('TS-AB123'), findsOneWidget);
    expect(find.text('Patient ID'), findsOneWidget);
    expect(find.text('15/06/1994'), findsNothing);
    expect(
      tester.widget<Text>(find.text('TS-AB123')).style?.fontSize,
      greaterThan(10),
    );

    await tester.pumpWidget(
      _localizedApp(
        Scaffold(
          body: DashboardHomeContent(
            patientName: 'Patient Name',
            dateOfBirth: dateOfBirth,
            patientState: DashboardPatientState.newPatient,
            onNavigate: (_) {},
            isLinkedPartner: true,
            partnerPermissions: const {'Patient profile information': true},
          ),
        ),
      ),
    );
    expect(find.text('Patient ID'), findsNothing);
    expect(find.text('TS-AB123'), findsNothing);
    expect(find.text('15/06/1994'), findsNothing);
  });

  testWidgets('Profile shows Patient ID below DOB without timezone shifts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const dateOfBirth = '1994-06-15T00:00:00.000Z';

    await tester.pumpWidget(
      _localizedApp(
        PatientProfileScreen(
          patientName: 'Patient Name',
          patientInitials: 'PN',
          patientId: 'TS-AB123',
          patientState: DashboardPatientState.newPatient,
          mobileNumber: '9876543210',
          dateOfBirth: dateOfBirth,
          preferredLanguage: 'English',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('15/06/1994'), findsOneWidget);
    expect(find.text('TS-AB123'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Patient ID')).dy,
      greaterThan(tester.getTopLeft(find.text('15/06/1994')).dy),
    );
    expect(
      tester.widget<Text>(find.text('TS-AB123')).style?.fontSize,
      greaterThan(10),
    );

    await tester.pumpWidget(
      _localizedApp(
        PatientProfileScreen(
          patientName: 'Patient Name',
          patientInitials: 'PN',
          patientState: DashboardPatientState.newPatient,
          mobileNumber: '9876543210',
          dateOfBirth: dateOfBirth,
          preferredLanguage: 'English',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Patient ID'), findsNothing);
    expect(find.text('15/06/1994'), findsOneWidget);
  });

  testWidgets('Profile and Personal Details display the number without +91', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _localizedApp(
        PatientProfileScreen(
          patientName: 'Patient Name',
          patientInitials: 'PN',
          patientState: DashboardPatientState.newPatient,
          mobileNumber: '+919876543210',
          dateOfBirth: '02/04/1994',
          preferredLanguage: 'English',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('+919876543210'), findsNothing);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('+919876543210'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('personal-details-update')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('personal-details-mobile')),
          )
          .controller
          ?.text,
      '9876543210',
    );
  });

  testWidgets(
    'Personal Details prefers authenticated profile data over stale local data',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final identity = await AccountIdentityService().createOrGetNewPatient(
        mobileNumber: '9123456789',
        fullName: 'Stale Local Name',
        dateOfBirth: '01/01/1980',
        preferredLanguage: 'English',
        email: 'stale@example.com',
      );

      await tester.pumpWidget(
        _localizedApp(
          PatientProfileScreen(
            patientName: 'Patient Name',
            patientInitials: 'PN',
            patientState: DashboardPatientState.newPatient,
            mobileNumber: '9876543210',
            email: 'patient@example.com',
            dateOfBirth: '02/04/1994',
            preferredLanguage: 'English',
            accountId: identity.accountId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Patient Name'), findsOneWidget);
      expect(find.text('02/04/1994'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('patient@example.com'), findsOneWidget);
      expect(find.text('Stale Local Name'), findsNothing);
      expect(find.text('01/01/1980'), findsNothing);
      expect(find.text('9123456789'), findsNothing);
      expect(find.text('stale@example.com'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
                        return const SendEmailOtpResponse(
                          challengeId: 'email-change-challenge',
                          expiresInSeconds: 300,
                          retryAfterSeconds: 30,
                        );
                      },
                      verifyOtp: (challengeId, email, otp) async =>
                          EmailChangeOtpVerificationResponse(
                            email: normalizeEmail(email),
                          ),
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
