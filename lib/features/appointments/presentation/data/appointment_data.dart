import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/notification_service.dart';
import '../models/appointment_models.dart';

const sampleDoctors = [
  Doctor(
    name: 'Dr. Meera Sharma',
    initials: 'MS',
    specialty: 'Fertility Specialist',
    languages: 'English · Hindi',
  ),
  Doctor(
    name: 'Dr. Ananya Rao',
    initials: 'AR',
    specialty: 'Reproductive Medicine',
    languages: 'English · Tamil',
  ),
  Doctor(
    name: 'Dr. Vikram Kapoor',
    initials: 'VK',
    specialty: 'Andrology Specialist',
    languages: 'English · Hindi',
  ),
];

final sampleAppointments = [
  Appointment(
    title: 'Monitoring consultation',
    date: DateTime(2026, 12, 12),
    time: '10:30 AM',
    clinic: 'Thaai Seyali Clinic',
    status: 'Confirmed',
    doctorName: 'Dr. Meera Sharma',
    specialty: 'Fertility Specialist',
    appointmentType: 'Monitoring consultation',
    consultationMode: 'In clinic',
    reference: 'PROTOTYPE-001',
  ),
  Appointment(
    title: 'Fertility consultation',
    date: DateTime(2026, 12, 18),
    time: '02:00 PM',
    clinic: 'Thaai Seyali Clinic',
    status: 'Requested',
    doctorName: 'Dr. Ananya Rao',
    specialty: 'Reproductive Medicine',
    appointmentType: 'Fertility consultation',
    consultationMode: 'Video consultation',
    reference: 'PROTOTYPE-002',
  ),
  Appointment(
    title: 'Follow-up consultation',
    date: DateTime(2026, 11, 20),
    time: '11:30 AM',
    clinic: 'Thaai Seyali Clinic',
    status: 'Rescheduled',
    doctorName: 'Dr. Vikram Kapoor',
    specialty: 'Andrology Specialist',
    appointmentType: 'Follow-up consultation',
    consultationMode: 'In clinic',
    reference: 'PROTOTYPE-003',
  ),
];

final sampleHistory = [
  Appointment(
    title: 'Initial consultation',
    date: DateTime(2026, 8, 8),
    time: '10:00 AM',
    clinic: 'Thaai Seyali Clinic',
    status: 'Completed',
    doctorName: 'Dr. Meera Sharma',
    appointmentType: 'Initial consultation',
    reference: 'PROTOTYPE-H01',
  ),
  Appointment(
    title: 'Follow-up consultation',
    date: DateTime(2026, 7, 17),
    time: '03:30 PM',
    clinic: 'Thaai Seyali Clinic',
    status: 'Cancelled',
    doctorName: 'Dr. Ananya Rao',
    appointmentType: 'Follow-up consultation',
    reference: 'PROTOTYPE-H02',
  ),
];

const _appointmentsKey = 'appointment_records';
const _historyKey = 'appointment_history';

final appointmentStore = AppointmentStore();
final _defaultAppointments = sampleAppointments
    .map((appointment) => Appointment.fromMap(appointment.toMap()))
    .toList();
final _defaultHistory = sampleHistory
    .map((appointment) => Appointment.fromMap(appointment.toMap()))
    .toList();
String? _activeAppointmentAccountId;

class AppointmentStore extends ChangeNotifier {
  List<Appointment> get upcoming => List.unmodifiable(sampleAppointments);
  List<Appointment> get history => List.unmodifiable(sampleHistory);

  Appointment? get nearestUpcoming {
    final eligible =
        sampleAppointments.where((appointment) {
          return appointment.status != 'Cancelled' &&
              appointment.status != 'Completed' &&
              appointmentDateTime(appointment).isAfter(DateTime.now());
        }).toList()..sort(
          (a, b) => appointmentDateTime(a).compareTo(appointmentDateTime(b)),
        );
    return eligible.isEmpty ? null : eligible.first;
  }

  void refresh() => notifyListeners();

  void clearActiveAccount() {
    _activeAppointmentAccountId = null;
    sampleAppointments
      ..clear()
      ..addAll(
        _defaultAppointments.map(
          (appointment) => Appointment.fromMap(appointment.toMap()),
        ),
      );
    sampleHistory
      ..clear()
      ..addAll(
        _defaultHistory.map(
          (appointment) => Appointment.fromMap(appointment.toMap()),
        ),
      );
    notifyListeners();
  }
}

Future<void> initializeAppointmentData({String? accountId}) async {
  _activeAppointmentAccountId = accountId;
  sampleAppointments
    ..clear()
    ..addAll(
      _defaultAppointments.map(
        (appointment) => Appointment.fromMap(appointment.toMap()),
      ),
    );
  sampleHistory
    ..clear()
    ..addAll(
      _defaultHistory.map(
        (appointment) => Appointment.fromMap(appointment.toMap()),
      ),
    );
  final preferences = await SharedPreferences.getInstance();
  final prefix = accountId == null || accountId.isEmpty
      ? ''
      : '${accountId}_';
  final appointmentsJson = preferences.getString('$prefix$_appointmentsKey');
  final historyJson = preferences.getString('$prefix$_historyKey');
  if (appointmentsJson != null) {
    sampleAppointments
      ..clear()
      ..addAll(_decode(appointmentsJson));
  }
  if (historyJson != null) {
    sampleHistory
      ..clear()
      ..addAll(_decode(historyJson));
  }
  appointmentStore.refresh();
}

Future<void> scheduleActiveAppointmentReminders() async {
  for (final appointment in sampleAppointments) {
    if (appointment.status != 'Cancelled' &&
        appointment.status != 'Completed') {
      await NotificationService.instance.scheduleReminder(appointment);
    }
  }
}

Future<void> addAppointment({
  required Doctor doctor,
  required DateTime date,
  required String time,
  required String patientName,
  required String appointmentType,
  required String consultationMode,
  required String notes,
}) async {
  final id = 'PROTOTYPE-${DateTime.now().microsecondsSinceEpoch}';
  final appointment = Appointment(
    title: appointmentType,
    date: date,
    time: time,
    clinic: 'Thaai Seyali Clinic',
    status: 'Requested',
    doctorName: doctor.name,
    specialty: doctor.specialty,
    appointmentType: appointmentType,
    consultationMode: consultationMode,
    patientName: patientName,
    notes: notes.isEmpty ? 'No additional notes.' : notes,
    reference: id,
  );
  sampleAppointments.add(appointment);
  await _save();
  await NotificationService.instance.showBookingSubmitted(appointment);
  await NotificationService.instance.scheduleReminder(appointment);
  appointmentStore.refresh();
}

Future<void> cancelAppointment(Appointment appointment) async {
  appointment.status = 'Cancelled';
  sampleAppointments.remove(appointment);
  if (!sampleHistory.contains(appointment)) {
    sampleHistory.insert(0, appointment);
  }
  await _save();
  await NotificationService.instance.cancelAppointmentNotifications(
    appointment,
  );
  await NotificationService.instance.showCancellation(appointment);
  appointmentStore.refresh();
}

DateTime appointmentDateTime(Appointment appointment) {
  final parts = appointment.time.split(' ');
  final clock = parts.first.split(':');
  var hour = int.parse(clock[0]);
  final minute = int.parse(clock[1]);
  if (parts.last == 'PM' && hour != 12) hour += 12;
  if (parts.last == 'AM' && hour == 12) hour = 0;
  return DateTime(
    appointment.date.year,
    appointment.date.month,
    appointment.date.day,
    hour,
    minute,
  );
}

Appointment? findAppointmentById(String reference) {
  for (final appointment in [...sampleAppointments, ...sampleHistory]) {
    if (appointment.reference == reference) return appointment;
  }
  return null;
}

List<Appointment> _decode(String value) {
  final records = jsonDecode(value) as List<dynamic>;
  return records
      .map((record) => Appointment.fromMap(record as Map<String, dynamic>))
      .toList();
}

Future<void> _save() async {
  final preferences = await SharedPreferences.getInstance();
  final prefix = _activeAppointmentAccountId == null ||
          _activeAppointmentAccountId!.isEmpty
      ? ''
      : '${_activeAppointmentAccountId}_';
  await preferences.setString(
    '$prefix$_appointmentsKey',
    jsonEncode(
      sampleAppointments.map((appointment) => appointment.toMap()).toList(),
    ),
  );
  await preferences.setString(
    '$prefix$_historyKey',
    jsonEncode(
      sampleHistory.map((appointment) => appointment.toMap()).toList(),
    ),
  );
}

const sampleTimeSlots = [
  '09:00 AM',
  '10:30 AM',
  '11:30 AM',
  '02:00 PM',
  '03:30 PM',
];
