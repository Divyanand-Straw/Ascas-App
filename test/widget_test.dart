import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/app.dart';
import 'package:app/core/services/notification_service.dart';
import 'package:app/features/appointments/presentation/appointment_dashboard_screen.dart';
import 'package:app/features/appointments/presentation/widgets/appointment_widgets.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/features/medical_records/presentation/medical_records_screen.dart';
import 'package:app/features/medication/presentation/medication_screen.dart';
import 'package:app/features/notifications/presentation/notifications_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('notifications are classified into patient-facing categories', () {
    InAppNotification notification(String title, String body) =>
        InAppNotification(
          title: title,
          body: body,
          appointmentId: '',
          createdAt: DateTime(2026),
        );

    expect(
      notification(
        'Appointment Request Submitted',
        'Awaiting confirmation',
      ).category,
      NotificationCategory.appointment,
    );
    expect(
      notification('Prescription updated', 'New medication schedule').category,
      NotificationCategory.medication,
    );
    expect(
      notification('Report uploaded', 'Your report is ready').category,
      NotificationCategory.medicalRecord,
    );
    expect(
      notification('Payment recorded', 'Invoice available').category,
      NotificationCategory.payment,
    );
    expect(
      notification('Treatment update', 'Milestone confirmed').category,
      NotificationCategory.journey,
    );
  });

  testWidgets('Thaai Seyazhi app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ThaaiSeyazhiApp());

    expect(find.text('THAAI SEYAZHI'), findsOneWidget);
  });

  testWidgets('medication screen does not invent a prescription or dose', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MedicationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No prescriptions available'), findsOneWidget);
    expect(find.text('No active prescriptions'), findsOneWidget);
    expect(find.text('Clinic prescription'), findsNothing);
    expect(find.text('Mark taken'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification screen shows the persisted empty state', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await NotificationService.instance.clearAll();
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointment requests do not show fabricated sample slots', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppointmentDashboardScreen(
            patientName: 'Patient',
            mobileNumber: '',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Submitted appointment requests will appear here when available.',
      ),
      findsOneWidget,
    );
    expect(find.text('14 May · 10:30 AM · Sample slot'), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets('billing summary fits a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BillsPaymentsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Billing overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('No recent clinic updates'), findsOneWidget);
    expect(find.text('Medication placeholder'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('More / Patient Services'), findsOneWidget);
    expect(find.text('Embryology Updates'), findsOneWidget);
    await tester.tap(find.text('Fertility History'));
    await tester.pumpAndSettle();
    expect(find.text('Clinic update pending'), findsWidgets);
    expect(find.text('Ovarian stimulation'), findsNothing);
    expect(find.text('8 April 2025'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reports').first);
    await tester.tap(find.text('Reports').first);
    await tester.pumpAndSettle();
    expect(find.text('Laboratory and imaging reports'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Medications').first);
    await tester.tap(find.text('Medications').first);
    await tester.pumpAndSettle();
    expect(find.text('Medication Management'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bills & Payments').first);
    await tester.tap(find.text('Bills & Payments').first);
    await tester.pumpAndSettle();
    expect(find.text('Billing overview'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 720);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Doctor Communication').first);
    await tester.tap(find.text('Doctor Communication').first);
    await tester.pumpAndSettle();
    expect(find.text('Communication & Support'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Fertility Education').first);
    await tester.tap(find.text('Fertility Education').first);
    await tester.pumpAndSettle();
    expect(find.text('Education Centre'), findsOneWidget);
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
    expect(find.text('Treatment timeline'), findsOneWidget);
    expect(
      find.text('Your clinic-confirmed treatment milestones will appear here.'),
      findsOneWidget,
    );
    expect(find.text('IUI Timeline'), findsNothing);
    await tester.ensureVisible(find.text('View appointment'));
    await tester.tap(find.text('View appointment'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment details'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('supported treatment types show clinic-managed journey states', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const treatmentStates = [
      (DashboardPatientState.ivf, 'IVF Cycle 1'),
      (DashboardPatientState.icsi, 'ICSI Treatment'),
      (DashboardPatientState.iui, 'IUI Treatment'),
      (DashboardPatientState.fet, 'Frozen Embryo Transfer (FET)'),
      (DashboardPatientState.embryoTransfer, 'Embryo Transfer'),
      (DashboardPatientState.twoWeekWait, 'Two-Week Wait'),
      (DashboardPatientState.followUpCare, 'Follow-up Care'),
      (DashboardPatientState.postProcedureRecovery, 'Follow-up Care'),
      (DashboardPatientState.newPatient, 'Care pathway pending'),
    ];

    for (final (state, treatmentName) in treatmentStates) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardScreen(
            patientName: 'Priya Sharma',
            patientState: state,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('My Journey'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(treatmentName), findsOneWidget);
      expect(
        find.text(
          'Your clinic-confirmed treatment milestones will appear here.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
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
    expect(find.text('சமீபத்திய மருத்துவமைய புதுப்பிப்புகள்'), findsOneWidget);
    expect(find.text('கட்டணச் சுருக்கம்'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('என் பயணம்'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('என் பயணம்'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
