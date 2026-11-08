import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/app.dart';
import 'package:app/features/appointments/presentation/widgets/appointment_widgets.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/features/medical_records/presentation/medical_records_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Thaai Seyazhi app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ThaaiSeyazhiApp());

    expect(find.text('THAAI SEYAZHI'), findsOneWidget);
  });

  testWidgets('billing search, bill details, and invoice preview work', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MedicalRecordsScreen()));
    await tester.tap(find.text('Bills & Payments'));
    await tester.pumpAndSettle();

    expect(find.text('Billing overview'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-BILL-001'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'does not exist');
    await tester.pumpAndSettle();
    expect(find.text('No matching bills'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-BILL-001'), findsOneWidget);

    await tester.ensureVisible(find.text('View bill details').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View bill details').first);
    await tester.pumpAndSettle();
    expect(find.text('Bill Details'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('No payment transactions are available.'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Invoice preview'));
    await tester.tap(find.text('Invoice preview'));
    await tester.pumpAndSettle();
    expect(
      find.text('Demo invoice preview. Not a clinic-issued invoice.'),
      findsOneWidget,
    );
  });

  testWidgets('IP billing shows the no-admissions empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MedicalRecordsScreen()));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IP Billing'));
    await tester.pumpAndSettle();

    expect(find.text('No Inpatient Billing Records'), findsOneWidget);
    expect(
      find.text(
        'Your inpatient billing details will appear here when they are available.',
      ),
      findsOneWidget,
    );
    expect(find.text('ADM-2026-001'), findsNothing);
  });

  testWidgets('dashboard home and journey fit narrow English layout', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(
          patientName: 'Priya Sharma',
          patientState: DashboardPatientState.ivf,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Good Morning'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('More / Patient Services'), findsOneWidget);
    expect(find.text('Embryology Updates'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Appointments'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Appointments'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(AppointmentCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Appointment details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Health Records'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Patient Records'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Patient profile'), findsOneWidget);
    expect(find.text('Language & Accessibility'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('My Journey'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('IUI Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard bottom navigation fits Tamil labels', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(
          patientName: 'Priya Sharma',
          patientState: DashboardPatientState.ivf,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('முகப்பு'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('என் பயணம்'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('என் பயணம்'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
