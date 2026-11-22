import 'package:app/core/localization/localized_text.dart';
import 'package:app/core/services/locale_service.dart';
import 'package:app/features/appointments/presentation/appointment_detail_screen.dart';
import 'package:app/features/appointments/presentation/appointment_history_screen.dart';
import 'package:app/features/appointments/presentation/data/appointment_data.dart';
import 'package:app/features/appointments/presentation/models/appointment_models.dart';
import 'package:app/features/dashboard/presentation/widgets/dashboard_home_content.dart';
import 'package:app/features/dashboard/presentation/widgets/patient_profile_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _localizedApp(Locale locale, Widget home) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('appointment history labels and data are localized in Tamil', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(const Locale('ta'), const AppointmentHistoryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('சந்திப்பு வரலாறு'), findsOneWidget);
    expect(find.text('அனைத்தும்'), findsOneWidget);
    expect(find.text('முடிக்கப்பட்டது'), findsWidgets);
    expect(find.text('ரத்து செய்யப்பட்டது'), findsWidgets);
    expect(find.textContaining('8 ஆகஸ்ட் 2026'), findsOneWidget);
    expect(find.text('முதற்கட்ட ஆலோசனை'), findsOneWidget);
    expect(find.text('மருத்துவமையத்தில்'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointment history continues to display English', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(const Locale('en'), const AppointmentHistoryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appointment history'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.textContaining('8 August 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointment history empty state is localized', (tester) async {
    sampleHistory.clear();
    appointmentStore.refresh();
    addTearDown(appointmentStore.clearActiveAccount);

    await tester.pumpWidget(
      _localizedApp(const Locale('ta'), const AppointmentHistoryScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('சந்திப்பு வரலாறு எதுவும் இல்லை.'), findsOneWidget);

    await tester.pumpWidget(
      _localizedApp(const Locale('en'), const AppointmentHistoryScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('No appointment history yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home appointment actions fit narrow layouts and work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appointment = Appointment(
      title: 'A very long appointment title that must wrap without overflow',
      date: DateTime.now().add(const Duration(days: 3)),
      time: '10:30 AM',
      clinic: 'Thaai Seyali Clinic with an additional long location name',
      status: 'Confirmed',
      doctorName: 'Dr. A Doctor Name That Is Much Longer Than Usual',
      specialty: 'A very long specialty name for responsive layout testing',
      appointmentType:
          'A very long appointment type that must not overflow the card',
      consultationMode: 'In clinic',
      preparationGuidance: [
        'Please bring all relevant records and arrive early for this appointment.',
      ],
    );
    sampleAppointments
      ..clear()
      ..add(appointment);
    appointmentStore.refresh();
    addTearDown(appointmentStore.clearActiveAccount);

    await tester.pumpWidget(
      _localizedApp(
        const Locale('en'),
        Scaffold(
          body: SingleChildScrollView(
            child: DashboardHomeContent(
              patientName: 'Patient',
              patientState: DashboardPatientState.ivf,
              onNavigate: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Instructions'));

    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Instructions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Instructions'));
    await tester.pumpAndSettle();
    expect(find.text('Preparation guidance'), findsOneWidget);
    expect(
      find.text(
        'Please bring all relevant records and arrive early for this appointment.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View Details'));
    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language selection applies only on save and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.resetForLogout();
    await LocaleService.setAccount('language-test-account');
    await tester.pumpWidget(const _LanguagePreferenceHarness());

    expect(find.text('Appointment history'), findsOneWidget);
    await tester.tap(find.text('Open language preferences'));
    await tester.pumpAndSettle();
    await _selectTamil(tester);

    expect(LocaleService.locale.value, const Locale('en'));
    expect(find.text('Language & Accessibility'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(LocaleService.locale.value, const Locale('en'));

    await tester.tap(find.text('Open language preferences'));
    await tester.pumpAndSettle();
    await _selectTamil(tester);
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();

    expect(LocaleService.locale.value, const Locale('ta'));
    expect(find.text('சந்திப்பு வரலாறு'), findsOneWidget);
    expect(find.text('முகப்பு'), findsOneWidget);
    expect(find.text('என் பயணம்'), findsOneWidget);
    expect(find.text('சந்திப்புகள்'), findsOneWidget);
    expect(find.text('சுகாதாரப் பதிவுகள்'), findsOneWidget);
    expect(find.text('சுயவிவரம்'), findsOneWidget);
    expect(find.text('மேலும்'), findsOneWidget);
    expect(
      await LocaleService.languageForAccount('language-test-account'),
      'ta',
    );

    await LocaleService.resetForLogout();
    await tester.pumpAndSettle();
    expect(find.text('Appointment history'), findsOneWidget);
    await LocaleService.setAccount('language-test-account');
    await tester.pumpAndSettle();
    expect(LocaleService.locale.value, const Locale('ta'));
    expect(find.text('சந்திப்பு வரலாறு'), findsOneWidget);
  });
}

Future<void> _selectTamil(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tamil').last);
  await tester.pumpAndSettle();
}

class _LanguagePreferenceHarness extends StatelessWidget {
  const _LanguagePreferenceHarness();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: LocaleService.locale,
    builder: (context, locale, _) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const LocalizedText('Appointment history'),
              Text(AppLocalizations.of(context)!.home),
              Text(AppLocalizations.of(context)!.myJourney),
              Text(AppLocalizations.of(context)!.appointments),
              Text(AppLocalizations.of(context)!.healthRecords),
              Text(AppLocalizations.of(context)!.profile),
              Text(AppLocalizations.of(context)!.more),
              ElevatedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LanguageAccessibilityScreen(
                      selectedLanguage: 'English',
                      accountId: 'language-test-account',
                    ),
                  ),
                ),
                child: const Text('Open language preferences'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
