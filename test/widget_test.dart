import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/app.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/services/notification_service.dart';
import 'package:app/core/widgets/date_of_birth_picker.dart';
import 'package:app/features/auth/presentation/new_patient/patient_details_screen.dart'
    as new_patient;
import 'package:app/features/appointments/presentation/appointment_dashboard_screen.dart';
import 'package:app/features/appointments/presentation/data/appointment_data.dart';
import 'package:app/features/appointments/presentation/doctor_information_screen.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/features/dashboard/presentation/journey_sections.dart';
import 'package:app/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:app/features/dashboard/data/treatment_journey_data.dart';
import 'package:app/features/medical_records/presentation/medical_records_screen.dart';
import 'package:app/features/medication/presentation/medication_screen.dart';
import 'package:app/features/medication/presentation/demo_reminder_card.dart';
import 'package:app/features/medication/data/medication_reminder.dart';
import 'package:app/features/notifications/presentation/notifications_screen.dart';
import 'package:app/features/partner_access/data/partner_link_service.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpLiveDashboard(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

Future<void> _pumpRouteTransition(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void main() {
  test(
    'date of birth parsing accepts supported formats and rejects bad dates',
    () {
      expect(parseDateOfBirth('14/08/1992'), DateTime(1992, 8, 14));
      expect(parseDateOfBirth('1992-08-14'), DateTime(1992, 8, 14));
      expect(parseDateOfBirth('31/02/1992'), isNull);
      expect(formatDateOfBirth(DateTime(1992, 8, 14)), '14/08/1992');
    },
  );

  testWidgets('new patient birthday calendar opens at a sensible date', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: new_patient.PatientDetailsScreen(mobileNumber: '9876543210'),
      ),
    );
    await tester.tap(find.byType(TextFormField).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Select year'), findsOneWidget);
    final year = DateTime.now().year - 30;
    await tester.tap(find.text('$year'));
    await tester.pumpAndSettle();

    expect(find.text('Select month · $year'), findsOneWidget);
    await tester.tap(find.text('April'));
    await tester.pumpAndSettle();

    final calendar = tester.widget<CalendarDatePicker>(
      find.byKey(const ValueKey('dob-day-calendar')),
    );
    expect(calendar.initialDate?.year, year);
    expect(calendar.initialDate?.month, 4);
    final secondDay = find.descendant(
      of: find.byKey(const ValueKey('dob-day-calendar')),
      matching: find.text('2'),
    );
    await tester.tap(secondDay.first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller
          ?.text,
      '02/04/$year',
    );
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('Thaai Seyali app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ThaaiSeyazhiApp());

    expect(find.text('THAAI SEYALI'), findsOneWidget);
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

  testWidgets('Your Next Visit updates when an appointment is submitted', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await initializeAppointmentData(accountId: '');
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppointmentDashboardScreen(
            patientName: 'Priya Sharma',
            mobileNumber: '9876543210',
          ),
        ),
      ),
    );
    await tester.pump();

    await addAppointment(
      doctor: sampleDoctors.first,
      date: DateTime.now().add(const Duration(days: 1)),
      time: '09:00 AM',
      patientName: 'Priya Sharma',
      appointmentType: 'New appointment request',
      consultationMode: 'In clinic',
      notes: '',
    );
    await tester.pump();

    expect(find.text('New appointment request'), findsOneWidget);
    expect(find.text('YOUR NEXT VISIT'), findsOneWidget);
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
    await _pumpLiveDashboard(tester);
    final hour = DateTime.now().hour;
    final expectedGreeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    expect(find.text(expectedGreeting), findsOneWidget);
    expect(find.text('Recent Clinic Updates'), findsNothing);
    expect(find.text('Billing Overview'), findsNothing);
    expect(find.text('SAMPLE DATA · NOT A PRESCRIPTION'), findsOneWidget);
    expect(find.text('IP Billing'), findsNothing);
    expect(find.text('Request Appointment'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Appointments'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(find.text('Appointments'), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(find.text('No upcoming appointments.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Health Records'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(find.text('Patient Records'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(find.text('Patient profile'), findsOneWidget);
    expect(find.text('Language & Accessibility'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('My Journey'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(find.text('Ovulation Tracker'), findsOneWidget);
    expect(find.text('IUI Timeline'), findsOneWidget);
    expect(find.text('IVF Timeline'), findsOneWidget);
    expect(find.text('Medication Schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('newly requested appointment updates the Home next appointment', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await initializeAppointmentData(accountId: '');
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(
          patientName: 'Priya Sharma',
          mobileNumber: '9876543210',
        ),
      ),
    );
    await _pumpLiveDashboard(tester);

    await addAppointment(
      doctor: sampleDoctors.first,
      date: DateTime.now().add(const Duration(days: 1)),
      time: '09:00 AM',
      patientName: 'Priya Sharma',
      appointmentType: 'New appointment request',
      consultationMode: 'In clinic',
      notes: '',
    );
    expect(
      appointmentStore.nearestUpcoming?.appointmentType,
      'New appointment request',
    );
    await _pumpLiveDashboard(tester);

    expect(find.textContaining('New appointment request'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Request Appointment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home Our Doctors View All opens the doctor listing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(
          patientName: 'Priya Sharma',
          mobileNumber: '9876543210',
        ),
      ),
    );
    await _pumpLiveDashboard(tester);
    final doctorsHeader = find.ancestor(
      of: find.text('Our Doctors'),
      matching: find.byType(DashboardSectionHeader),
    );
    await tester.ensureVisible(doctorsHeader);
    expect(
      tester.widget<DashboardSectionHeader>(doctorsHeader).onAction,
      isNotNull,
    );
    final viewAllButton = find.descendant(
      of: doctorsHeader,
      matching: find.byType(TextButton),
    );
    expect(viewAllButton.hitTestable(), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(DashboardScreen))).canPop(),
      isFalse,
    );
    await tester.tap(viewAllButton);
    await _pumpLiveDashboard(tester);
    await _pumpRouteTransition(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(DoctorInformationScreen), findsOneWidget);
    expect(find.text('Search by doctor or specialty'), findsOneWidget);
    expect(find.text('Dr. Meera Sharma'), findsOneWidget);
    await tester.ensureVisible(find.text('View profile').first);
    expect(find.text('View profile'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sample reminders count down, show their prescription, and can be taken',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: const [DemoReminderCard(showAll: true)]),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(
          'Sample schedules are for app demonstration only. They are not medical advice or an actual treatment plan.',
        ),
        findsNothing,
      );
      expect(find.text('Sample schedule · once daily'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.style?.fontSize == 19 &&
              widget.style?.fontWeight == FontWeight.w800,
        ),
        findsNWidgets(3),
      );
      final countdownFinder = find
          .byWidgetPredicate(
            (widget) =>
                widget is Text &&
                RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
          )
          .first;
      final initial = tester.widget<Text>(countdownFinder).data;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Text>(countdownFinder).data, isNot(initial));

      final selectedReminder = find.ancestor(
        of: find.text('Vitamin D · sample only'),
        matching: find.byType(MedicationReminderCard),
      );
      final prescriptionButton = find.descendant(
        of: selectedReminder,
        matching: find.text('View Prescription'),
      );
      await tester.ensureVisible(prescriptionButton);
      expect(prescriptionButton.hitTestable(), findsOneWidget);
      final prescriptionTextButton = find.ancestor(
        of: prescriptionButton,
        matching: find.byType(TextButton),
      );
      expect(
        tester.widget<TextButton>(prescriptionTextButton.first).onPressed,
        isNotNull,
      );
      expect(
        Navigator.of(tester.element(prescriptionButton)).canPop(),
        isFalse,
      );
      await tester.tap(prescriptionButton);
      expect(Navigator.of(tester.element(prescriptionButton)).canPop(), isTrue);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(find.byType(PrescriptionDetailsScreen), findsOneWidget);
      final prescriptionDetails = tester.widget<PrescriptionDetailsScreen>(
        find.byType(PrescriptionDetailsScreen),
      );
      expect(prescriptionDetails.reminder.id, 'sample-afternoon');
      await tester.pageBack();
      await _pumpRouteTransition(tester);

      await tester.tap(
        find.descendant(
          of: selectedReminder,
          matching: find.text('Mark as Taken'),
        ),
      );
      await tester.pump();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Mark as Taken'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sample prescription details show structured fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrescriptionDetailsScreen(reminder: sampleMedicationReminders[1]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D · sample only'), findsWidgets);
    expect(find.text('Prescribed dosage'), findsOneWidget);
    expect(find.text('Instructions'), findsOneWidget);
    expect(find.text('Frequency'), findsOneWidget);
    expect(find.text('Prescribing doctor'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    expect(find.text('Patient Records'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('sample reminder status transitions are date-aware', () {
    final reminder = sampleMedicationReminders.first;
    final schedule = DateTime(2026, 11, 9, reminder.hour, reminder.minute);
    expect(
      medicationReminderStatus(
        reminder: reminder,
        now: schedule.subtract(const Duration(minutes: 1)),
      ),
      MedicationReminderStatus.upcoming,
    );
    expect(
      medicationReminderStatus(
        reminder: reminder,
        now: schedule.add(const Duration(minutes: 30)),
      ),
      MedicationReminderStatus.due,
    );
    expect(
      medicationReminderStatus(
        reminder: reminder,
        now: schedule.add(const Duration(hours: 2)),
      ),
      MedicationReminderStatus.missed,
    );
    expect(
      medicationReminderStatus(
        reminder: reminder,
        now: schedule.add(const Duration(hours: 2)),
        takenAt: schedule.add(const Duration(hours: 2)),
      ),
      MedicationReminderStatus.completed,
    );

    final service = NotificationService.instance;
    expect(
      service.medicationNotificationIdForTesting('patient-1', reminder.id),
      service.medicationNotificationIdForTesting('patient-1', reminder.id),
    );
    expect(
      service.medicationNotificationIdForTesting('patient-1', reminder.id),
      isNot(
        service.medicationNotificationIdForTesting('patient-2', reminder.id),
      ),
    );
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

    for (final (state, _) in treatmentStates) {
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
      await _pumpLiveDashboard(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('My Journey'),
        ),
      );
      await _pumpLiveDashboard(tester);
      expect(find.text('Ovulation Tracker'), findsOneWidget);
      expect(find.text('IUI Timeline'), findsOneWidget);
      expect(find.text('IVF Timeline'), findsOneWidget);
      expect(find.text('Medication Schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('treatment pathway overviews distinguish IVF, ICSI, IUI, and FET', () {
    expect(workflowStagesFor('IVF Cycle 1'), contains('Ovarian stimulation'));
    expect(
      workflowStagesFor('ICSI Treatment'),
      contains('ICSI fertilisation and embryo culture'),
    );
    expect(workflowStagesFor('IUI Treatment'), contains('Insemination'));
    expect(
      workflowStagesFor('Frozen Embryo Transfer (FET)'),
      contains('Frozen embryo transfer'),
    );
  });

  testWidgets('four Journey sections open their dedicated interactive pages', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(
          patientName: 'Priya Sharma',
          patientState: DashboardPatientState.ivf,
        ),
      ),
    );
    await _pumpLiveDashboard(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('My Journey'),
      ),
    );
    await _pumpLiveDashboard(tester);

    await tester.ensureVisible(find.text('IUI Timeline'));
    expect(
      tester
          .widget<JourneySectionCard>(find.byType(JourneySectionCard).at(1))
          .onTap,
      isNotNull,
    );
    expect(find.byType(JourneySectionCard).at(1).hitTestable(), findsOneWidget);
    await tester.tap(find.byType(JourneySectionCard).at(1));
    await _pumpLiveDashboard(tester);
    await _pumpRouteTransition(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(TreatmentTimelineScreen), findsOneWidget);
    expect(find.text('Initial consultation'), findsOneWidget);
    expect(find.text('Awaiting clinic update'), findsWidgets);
    final firstMilestone = find.ancestor(
      of: find.text('Initial consultation'),
      matching: find.byType(ListTile),
    );
    await tester.tap(firstMilestone);
    await _pumpLiveDashboard(tester);
    expect(
      find.text(
        'Guide only. This stage is not confirmed as part of your personal treatment plan.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await _pumpLiveDashboard(tester);
    final milestoneDisclaimer = find.text(
      'No milestone is marked complete unless your clinic provides that status.',
    );
    await tester.scrollUntilVisible(
      milestoneDisclaimer,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(milestoneDisclaimer, findsOneWidget);
    await tester.pageBack();
    await _pumpLiveDashboard(tester);

    await tester.ensureVisible(find.text('IVF Timeline'));
    await tester.tap(find.byType(JourneySectionCard).at(2));
    await _pumpLiveDashboard(tester);
    await _pumpRouteTransition(tester);
    expect(find.text('Egg retrieval'), findsOneWidget);
    expect(find.text('Embryo transfer, if applicable'), findsOneWidget);
    await tester.pageBack();
    await _pumpLiveDashboard(tester);

    await tester.ensureVisible(find.text('Ovulation Tracker'));
    await tester.tap(find.byType(JourneySectionCard).first);
    await _pumpLiveDashboard(tester);
    await _pumpRouteTransition(tester);
    expect(find.text('Cycle calendar'), findsOneWidget);
    expect(find.textContaining('Not entered'), findsWidgets);
    await tester.pageBack();
    await _pumpLiveDashboard(tester);

    await tester.ensureVisible(find.text('Medication Schedule'));
    await tester.tap(find.byType(JourneySectionCard).last);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.byType(MedicationScheduleScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Daily schedule'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Daily schedule'), findsOneWidget);
    expect(find.text('SAMPLE DATA · NOT A PRESCRIPTION'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('detailed cycle view opens, navigates months, and selects days', (
    WidgetTester tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final lastPeriod = today.subtract(const Duration(days: 8));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OvulationTrackerScreen(),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('View Detailed Cycle'));
    await tester.pumpAndSettle();
    expect(find.text('View Detailed Cycle'), findsOneWidget);
    await tester.tap(find.text('View Detailed Cycle'));
    await tester.pumpAndSettle();
    expect(find.byType(CycleDetailsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CycleDetailsScreen(
          lastPeriod: lastPeriod,
          cycleLength: 28,
          remindersEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    final nextMonth = DateTime(today.year, today.month + 1, 10);
    final monthNames = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    expect(find.text(monthNames[nextMonth.month - 1]), findsOneWidget);
    expect(find.text(' ${nextMonth.year}'), findsOneWidget);

    await tester.tap(
      find.byKey(
        ValueKey(
          'cycle-day-${nextMonth.year}-${nextMonth.month}-${nextMonth.day}',
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('${nextMonth.day}/${nextMonth.month}/${nextMonth.year}'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Cycle progression'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cycle progression'), findsOneWidget);
    expect(find.textContaining('estimate'), findsWidgets);
    expect(lastPeriod.isBefore(today), isTrue);
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
    await _pumpLiveDashboard(tester);
    expect(find.text('முகப்பு'), findsOneWidget);
    expect(find.text('சமீபத்திய மருத்துவமைய புதுப்பிப்புகள்'), findsNothing);
    expect(find.text('கட்டணச் சுருக்கம்'), findsNothing);
    expect(find.text('மாதிரி தகவல் · மருந்துச் சீட்டு அல்ல'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('என் பயணம்'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(find.text('என் பயணம்'), findsWidgets);
    expect(find.text('அண்டவிடுப்புக் கண்காணிப்பு'), findsOneWidget);
    expect(find.text('IUI காலவரிசை'), findsOneWidget);
    expect(find.text('IVF காலவரிசை'), findsOneWidget);
    expect(find.text('மருந்து அட்டவணை'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('patient profile header uses burgundy and compact patient ID', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(
          patientName: 'Priya Sharma',
          patientId: 'TS-12345',
          mobileNumber: '9876543210',
          dateOfBirth: '01/01/1990',
        ),
      ),
    );
    await _pumpLiveDashboard(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await _pumpLiveDashboard(tester);

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Patient ID: TS-12345'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('01/01/1990'), findsOneWidget);
    final profileHeader = find.ancestor(
      of: find.text('Patient ID: TS-12345'),
      matching: find.byType(DashboardCard),
    );
    expect(
      tester.widget<DashboardCard>(profileHeader.first).color,
      AppColors.burgundy,
    );
    expect(
      tester.widget<Text>(find.text('Patient ID: TS-12345')).style?.fontSize,
      8,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked partner accesses the account after accepting invitation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final links = PartnerLinkService();
    final invitation = await links.generateInvitation(
      patientUserId: 'user:patient',
      patientId: 'AS-20481',
      patientName: 'Ananya Iyer',
      patientMobile: '9876543210',
      patientState: DashboardPatientState.ivf.name,
    );
    final request = await links.submitRequest(
      code: invitation.invitationCode,
      partnerName: 'Partner Account',
      partnerMobile: '9123456780',
      partnerUserId: 'user:partner',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(
          patientName: 'Ananya Iyer',
          patientId: 'AS-20481',
          accountId: 'user:partner',
          isLinkedPartner: true,
          partnerUserName: 'Partner Account',
          partnerMobile: '9123456780',
          partnerLinkId: request.linkId,
          dataOwnerAccountId: 'user:patient',
        ),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(
      find.text(
        'Patient link is no longer active. Shared information is unavailable.',
      ),
      findsNothing,
    );
    expect(find.text('AS-20481'), findsNothing);

    await links.savePermissions(request.linkId, {
      'Patient profile information': true,
      'Treatment Journey': true,
    });
    await _pumpLiveDashboard(tester);
    expect(
      find.text("Viewing Ananya Iyer's Linked Patient Profile"),
      findsOneWidget,
    );
    expect(find.textContaining('AS-20481'), findsOneWidget);
    expect(find.text('Partner Account'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('My Journey'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(find.text('IUI Timeline'), findsOneWidget);
    expect(find.text('IVF Timeline'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Appointments'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(
      find.text('The patient has not shared Appointments with this account.'),
      findsOneWidget,
    );
    await links.savePermissions(request.linkId, {
      'Patient profile information': true,
      'Treatment Journey': false,
    });
    await _pumpLiveDashboard(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('My Journey'),
      ),
    );
    await _pumpLiveDashboard(tester);
    expect(
      find.text(
        'The patient has not shared the Treatment Journey with this account.',
      ),
      findsOneWidget,
    );

    await links.revokeAccess(request.linkId);
    await _pumpLiveDashboard(tester);
    expect(
      find.text(
        'Patient link is no longer active. Shared information is unavailable.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
