import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/appointments/presentation/models/appointment_models.dart';
import '../../features/medication/data/medication_reminder.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final instance = NotificationService._();
  static const _channelId = 'appointment_notifications';
  static const _channelName = 'Appointments';
  static const _channelDescription =
      'Appointment requests and appointment reminders';
  static const _medicationChannelId = 'medication_reminders';
  static const _medicationChannelName = 'Medication reminders';
  static const _medicationChannelDescription =
      'Scheduled medication reminder notifications';
  static const _scheduledMedicationIdsKey = 'scheduled_medication_ids';

  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String appointmentId)? onAppointmentNotificationTap;
  bool _initialized = false;
  bool? _notificationsPermissionGranted;
  final List<InAppNotification> _inbox = [];
  static const _inboxKey = 'appointment_notification_inbox';
  String _activeAccountId = 'guest';

  List<InAppNotification> get inbox => List.unmodifiable(_inbox);
  int get unreadCount =>
      _inbox.where((notification) => !notification.isRead).length;
  bool get isInitialized => _initialized;
  String get activeAccountId => _activeAccountId;
  bool get _supportsLocalNotifications =>
      _initialized &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> setAccount(String accountId) async {
    if (accountId == _activeAccountId) return;
    await _saveInbox();
    await _cancelMedicationNotificationsForAccount(_activeAccountId);
    _activeAccountId = accountId;
    _inbox.clear();
    await _loadInbox();
    notifyListeners();
  }

  Future<void> resetForLogout() async {
    await _saveInbox();
    await _cancelMedicationNotificationsForAccount(_activeAccountId);
    _activeAccountId = 'guest';
    _inbox.clear();
    await _loadInbox();
    notifyListeners();
  }

  String get _accountInboxKey => _activeAccountId == 'guest'
      ? _inboxKey
      : '${_inboxKey}_$_activeAccountId';

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    await _loadInbox();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final settings = InitializationSettings(
      android: android,
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onAppointmentNotificationTap?.call(payload);
        }
      },
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    final androidPermission = await androidPlugin
        ?.requestNotificationsPermission();
    if (androidPermission != null) {
      _notificationsPermissionGranted = androidPermission;
    }
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosPermission = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosPermission != null) _notificationsPermissionGranted = iosPermission;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _medicationChannelId,
            _medicationChannelName,
            description: _medicationChannelDescription,
            importance: Importance.high,
          ),
        );
    _initialized = true;
  }

  Future<bool> scheduleMedicationReminders(
    Iterable<MedicationReminder> reminders,
  ) async {
    if (!_supportsLocalNotifications ||
        _notificationsPermissionGranted == false) {
      return false;
    }

    final scheduledIds = <String>{};
    for (final reminder in reminders) {
      final id = _medicationNotificationId(_activeAccountId, reminder.id);
      scheduledIds.add('$id');
      final scheduledAt = reminder.nextScheduledAt(DateTime.now());
      await _plugin.zonedSchedule(
        id,
        'Medication reminder · sample',
        '${reminder.name} · Scheduled time: ${_timeLabel(reminder.hour, reminder.minute)}',
        tz.TZDateTime.from(scheduledAt, tz.local),
        _medicationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'medication:${reminder.id}',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _scheduledMedicationIdsPreferenceKey(_activeAccountId),
      scheduledIds.toList(),
    );
    return true;
  }

  Future<void> showBookingSubmitted(Appointment appointment) async {
    await _show(
      id: _bookingId(appointment),
      title: 'Appointment Request Submitted',
      body:
          'Your appointment request with ${appointment.doctorName} for ${_date(appointment.date)} at ${appointment.time} has been submitted successfully. Awaiting clinic confirmation.',
      appointment: appointment,
    );
  }

  Future<void> scheduleReminder(Appointment appointment) async {
    if (!_supportsLocalNotifications) return;
    final appointmentTime = _appointmentDateTime(appointment);
    final reminderTime = appointmentTime.subtract(const Duration(days: 1));
    if (appointmentTime.isBefore(DateTime.now()) ||
        !reminderTime.isAfter(DateTime.now())) {
      return;
    }
    await _plugin.zonedSchedule(
      _reminderId(appointment),
      'Appointment Reminder',
      'Reminder: You have an appointment with ${appointment.doctorName} tomorrow at ${appointment.time}. Please plan your visit accordingly.',
      tz.TZDateTime.from(reminderTime, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: appointment.reference,
    );
  }

  Future<void> cancelAppointmentNotifications(Appointment appointment) async {
    await _plugin.cancel(_bookingId(appointment));
    await _plugin.cancel(_reminderId(appointment));
  }

  Future<void> showCancellation(Appointment appointment) async {
    await _show(
      id: _cancellationId(appointment),
      title: 'Appointment Cancelled',
      body:
          'Your appointment with ${appointment.doctorName} scheduled for ${_date(appointment.date)} at ${appointment.time} has been cancelled successfully.',
      appointment: appointment,
    );
  }

  Future<void> showReschedulingRequest(Appointment appointment) async {
    await _show(
      id: _rescheduleId(appointment),
      title: 'Rescheduling Request Submitted',
      body:
          'Your request to reschedule your appointment with ${appointment.doctorName} has been submitted.',
      appointment: appointment,
    );
  }

  Future<void> showPartnerLinkRequest({
    required String partnerName,
    required String partnerMobile,
    required String linkId,
  }) async {
    const title = 'Partner linking request';
    final body =
        '$partnerName ($partnerMobile) requested access to your patient profile. Review the request in Partner Access.';
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await _plugin.show(
        linkId.hashCode & 0x7fffffff,
        title,
        body,
        _details(),
        payload: 'partner-link:$linkId',
      );
    }
    await _addToInbox(title, body, '');
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required Appointment appointment,
  }) async {
    if (_supportsLocalNotifications) {
      await _plugin.show(
        id,
        title,
        body,
        _details(),
        payload: appointment.reference,
      );
    }
    await _addToInbox(title, body, appointment.reference);
  }

  Future<void> markAllRead() async {
    for (final notification in _inbox) {
      notification.isRead = true;
    }
    await _saveInbox();
    notifyListeners();
  }

  Future<void> markRead(InAppNotification notification) async {
    if (notification.isRead) return;
    notification.isRead = true;
    await _saveInbox();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _inbox.clear();
    await _saveInbox();
    notifyListeners();
  }

  Future<void> _addToInbox(
    String title,
    String body,
    String appointmentId,
  ) async {
    _inbox.insert(
      0,
      InAppNotification(
        title: title,
        body: body,
        appointmentId: appointmentId,
        createdAt: DateTime.now(),
      ),
    );
    await _saveInbox();
    notifyListeners();
  }

  Future<void> _loadInbox() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_accountInboxKey);
    if (encoded == null) return;
    _inbox
      ..clear()
      ..addAll(InAppNotification.decode(encoded));
  }

  Future<void> _saveInbox() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _accountInboxKey,
      InAppNotification.encode(_inbox),
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  NotificationDetails _medicationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _medicationChannelId,
        _medicationChannelName,
        channelDescription: _medicationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> _cancelMedicationNotificationsForAccount(
    String accountId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _scheduledMedicationIdsPreferenceKey(accountId);
    final ids = preferences.getStringList(key) ?? const <String>[];
    if (_supportsLocalNotifications) {
      for (final id in ids) {
        await _plugin.cancel(int.parse(id));
      }
    }
    await preferences.remove(key);
  }

  String _scheduledMedicationIdsPreferenceKey(String accountId) =>
      '${_scheduledMedicationIdsKey}_$accountId';

  int _medicationNotificationId(String accountId, String reminderId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in '$accountId:$reminderId'.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return (hash & 0x3fffffff) | 0x40000000;
  }

  @visibleForTesting
  int medicationNotificationIdForTesting(String accountId, String reminderId) =>
      _medicationNotificationId(accountId, reminderId);

  String _timeLabel(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  DateTime _appointmentDateTime(Appointment appointment) {
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

  String _date(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

  int _bookingId(Appointment appointment) =>
      appointment.reference.hashCode & 0x3fffffff;
  int _reminderId(Appointment appointment) =>
      (_bookingId(appointment) + 1) & 0x3fffffff;
  int _cancellationId(Appointment appointment) =>
      (_bookingId(appointment) + 2) & 0x3fffffff;
  int _rescheduleId(Appointment appointment) =>
      (_bookingId(appointment) + 3) & 0x3fffffff;

  @visibleForTesting
  DateTime appointmentDateTimeForTesting(Appointment appointment) =>
      _appointmentDateTime(appointment);
}

enum NotificationCategory {
  medication,
  appointment,
  clinicMessage,
  appointmentConfirmation,
  appointmentUpdated,
  journey,
  medicalRecord,
  payment,
  general,
}

class InAppNotification {
  final String title;
  final String body;
  final String appointmentId;
  final DateTime createdAt;
  bool isRead;

  NotificationCategory get category {
    final normalized = '$title $body'.toLowerCase();
    if (normalized.contains('medication') ||
        normalized.contains('prescription') ||
        normalized.contains('dose')) {
      return NotificationCategory.medication;
    }
    if (normalized.contains('appointment') ||
        normalized.contains('reschedul')) {
      return NotificationCategory.appointment;
    }
    if (normalized.contains('payment') ||
        normalized.contains('bill') ||
        normalized.contains('invoice')) {
      return NotificationCategory.payment;
    }
    if (normalized.contains('report') ||
        normalized.contains('medical record') ||
        normalized.contains('discharge')) {
      return NotificationCategory.medicalRecord;
    }
    if (normalized.contains('journey') ||
        normalized.contains('treatment') ||
        normalized.contains('milestone')) {
      return NotificationCategory.journey;
    }
    if (normalized.contains('clinic') || normalized.contains('message')) {
      return NotificationCategory.clinicMessage;
    }
    return NotificationCategory.general;
  }

  InAppNotification({
    required this.title,
    required this.body,
    required this.appointmentId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, Object?> toMap() => {
    'title': title,
    'body': body,
    'appointmentId': appointmentId,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  static String encode(List<InAppNotification> notifications) {
    return jsonEncode(
      notifications.map((notification) => notification.toMap()).toList(),
    );
  }

  static List<InAppNotification> decode(String value) {
    final records = jsonDecode(value) as List<dynamic>;
    return records.map((record) {
      final map = record as Map<String, dynamic>;
      return InAppNotification(
        title: map['title'] as String,
        body: map['body'] as String,
        appointmentId: map['appointmentId'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        isRead: map['isRead'] as bool? ?? false,
      );
    }).toList();
  }
}
