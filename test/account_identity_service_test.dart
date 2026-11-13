import 'dart:convert';

import 'package:app/features/auth/data/account_identity_service.dart';
import 'package:app/features/appointments/presentation/data/appointment_data.dart';
import 'package:app/features/appointments/presentation/models/appointment_models.dart';
import 'package:app/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AccountIdentityService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = AccountIdentityService();
  });

  test(
    'new patient registration is idempotent and keeps account ID distinct',
    () async {
      final first = await service.createOrGetNewPatient(
        mobileNumber: '9876543210',
        fullName: 'New Patient',
        dateOfBirth: '02/04/1994',
        preferredLanguage: 'Tamil',
        gender: 'Female',
      );
      final retry = await service.createOrGetNewPatient(
        mobileNumber: '9876543210',
        fullName: 'Changed retry name',
        dateOfBirth: '01/01/2000',
        preferredLanguage: 'English',
      );

      expect(first.role, AccountRole.patient);
      expect(first.accountId, 'user:9876543210');
      expect(first.patientId, matches(RegExp(r'^TS-[A-Z]{2}\d{3}$')));
      expect(first.patientId, isNot(first.accountId));
      expect(retry.patientId, first.patientId);
      expect(retry.fullName, 'New Patient');
      expect(retry.dateOfBirth, '02/04/1994');
      expect(retry.gender, 'Female');
    },
  );

  test(
    'concurrent registration retries create only one patient identity',
    () async {
      final identities = await Future.wait(
        List.generate(
          4,
          (_) => service.createOrGetNewPatient(
            mobileNumber: '9876543210',
            fullName: 'New Patient',
            dateOfBirth: '02/04/1994',
            preferredLanguage: 'Tamil',
          ),
        ),
      );

      expect(
        identities.map((identity) => identity.patientId).toSet(),
        hasLength(1),
      );
    },
  );

  test(
    'existing patient verification matches the saved local identity',
    () async {
      final registered = await service.createOrGetNewPatient(
        mobileNumber: '9123456780',
        fullName: 'Existing Test Patient',
        dateOfBirth: '14/08/1992',
        preferredLanguage: 'Tamil',
        gender: 'Male',
      );
      final verified = await service.resolveExistingPatient(
        mobileNumber: registered.mobileNumber,
        patientId: registered.patientId,
        dateOfBirth: '1992-08-14',
      );

      expect(verified.accountId, registered.accountId);
      expect(verified.patientId, registered.patientId);
      expect(verified.fullName, 'Existing Test Patient');
      expect(verified.gender, 'Male');
      expect(
        (await service.createOrGetNewPatient(
          mobileNumber: registered.mobileNumber,
          fullName: 'An overwritten patient',
          dateOfBirth: '01/01/2000',
          preferredLanguage: 'English',
        )).fullName,
        'Existing Test Patient',
      );
      final stored = await service.accountForMobile(registered.mobileNumber);
      expect(stored?.accountId, verified.accountId);
      expect(stored?.patientId, verified.patientId);
    },
  );

  test(
    'different local test users receive separate dynamic patient identities',
    () async {
      final first = await service.createOrGetNewPatient(
        mobileNumber: '9876543210',
        fullName: 'First Test Patient',
        dateOfBirth: '02/04/1994',
        preferredLanguage: 'English',
      );
      final second = await service.createOrGetNewPatient(
        mobileNumber: '8765432109',
        fullName: 'Second Test Patient',
        dateOfBirth: '03/05/1993',
        preferredLanguage: 'Tamil',
      );

      expect(second.accountId, isNot(first.accountId));
      expect(first.patientId, matches(RegExp(r'^TS-[A-Z]{2}\d{3}$')));
      expect(second.patientId, matches(RegExp(r'^TS-[A-Z]{2}\d{3}$')));
      expect(second.patientId, isNot(first.patientId));
      expect(
        (await service.accountForMobile(first.mobileNumber))?.fullName,
        'First Test Patient',
      );
      expect(
        (await service.accountForMobile(second.mobileNumber))?.fullName,
        'Second Test Patient',
      );
    },
  );

  test(
    'existing patient lookup does not invent an unverified clinic account',
    () async {
      await expectLater(
        service.resolveExistingPatient(
          mobileNumber: '9123456780',
          patientId: 'UNKNOWN-MRN',
          dateOfBirth: '14/08/1992',
        ),
        throwsA(isA<StateError>()),
      );
      expect(await service.accountForMobile('9123456780'), isNull);
    },
  );

  test(
    'partner account has no patient ID and cannot become a patient account',
    () async {
      final partner = await service.createOrGetPartner(
        mobileNumber: '9123456780',
        fullName: 'Partner One',
      );
      expect(partner.role, AccountRole.partner);
      expect(partner.accountId, 'user:9123456780');
      expect(partner.patientId, isEmpty);
      await expectLater(
        service.createOrGetNewPatient(
          mobileNumber: '9123456780',
          fullName: 'Partner One',
          dateOfBirth: '01/01/1990',
          preferredLanguage: 'English',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('existing patient ID cannot bind to another mobile account', () async {
    final registered = await service.createOrGetNewPatient(
      mobileNumber: '9123456780',
      fullName: 'Patient One',
      dateOfBirth: '14/08/1992',
      preferredLanguage: 'English',
    );
    await expectLater(
      service.resolveExistingPatient(
        mobileNumber: '9123456781',
        patientId: registered.patientId,
        dateOfBirth: '14/08/1992',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'appointment and notification caches are scoped to the patient account',
    () async {
      final firstAppointment = Appointment(
        title: 'Patient A history',
        date: DateTime(2026, 9, 1),
        time: '10:00 AM',
        clinic: 'Clinic',
        status: 'Completed',
        patientName: 'Patient A',
        reference: 'A-1',
      );
      final secondAppointment = Appointment(
        title: 'Patient B history',
        date: DateTime(2026, 9, 2),
        time: '11:00 AM',
        clinic: 'Clinic',
        status: 'Completed',
        patientName: 'Patient B',
        reference: 'B-1',
      );
      final firstNotification = InAppNotification(
        title: 'Patient A clinic update',
        body: 'Patient A update',
        appointmentId: '',
        createdAt: DateTime(2026, 9, 1),
      );
      final secondNotification = InAppNotification(
        title: 'Patient B clinic update',
        body: 'Patient B update',
        appointmentId: '',
        createdAt: DateTime(2026, 9, 2),
      );
      SharedPreferences.setMockInitialValues({
        'patient-a_appointment_records': jsonEncode([firstAppointment.toMap()]),
        'patient-b_appointment_records': jsonEncode([
          secondAppointment.toMap(),
        ]),
        'appointment_notification_inbox_user:patient-a':
            InAppNotification.encode([firstNotification]),
        'appointment_notification_inbox_user:patient-b':
            InAppNotification.encode([secondNotification]),
      });

      await initializeAppointmentData(accountId: 'patient-a');
      expect(appointmentStore.upcoming.single.patientName, 'Patient A');
      await initializeAppointmentData(accountId: 'patient-b');
      expect(appointmentStore.upcoming.single.patientName, 'Patient B');
      appointmentStore.clearActiveAccount();

      final notifications = NotificationService.instance;
      await notifications.resetForLogout();
      await notifications.setAccount('user:patient-a');
      expect(notifications.inbox.single.title, 'Patient A clinic update');
      await notifications.setAccount('user:patient-b');
      expect(notifications.inbox.single.title, 'Patient B clinic update');
      await notifications.resetForLogout();
      expect(notifications.inbox, isEmpty);
    },
  );
}
