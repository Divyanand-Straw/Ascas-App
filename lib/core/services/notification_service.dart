import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/appointments/presentation/models/appointment_models.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final instance = NotificationService._();
  static const _channelId = 'appointment_notifications';
  static const _channelName = 'Appointments';
  static const _channelDescription =
      'Appointment requests and appointment reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String appointmentId)? onAppointmentNotificationTap;
  bool _initialized = false;
  final List<InAppNotification> _inbox = [];
  static const _inboxKey = 'appointment_notification_inbox';

  List<InAppNotification> get inbox => List.unmodifiable(_inbox);
  int get unreadCount =>
      _inbox.where((notification) => !notification.isRead).length;

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
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    _initialized = true;
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
    final appointmentTime = _appointmentDateTime(appointment);
    final reminderTime =
        appointmentTime.subtract(const Duration(days: 1));
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

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required Appointment appointment,
  }) async {
    await _plugin.show(id, title, body, _details(), payload: appointment.reference);
    await _addToInbox(title, body, appointment.reference);
  }

  Future<void> markAllRead() async {
    for (final notification in _inbox) {
      notification.isRead = true;
    }
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
    final encoded = preferences.getString(_inboxKey);
    if (encoded == null) return;
    _inbox
      ..clear()
      ..addAll(InAppNotification.decode(encoded));
  }

  Future<void> _saveInbox() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_inboxKey, InAppNotification.encode(_inbox));
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

class InAppNotification {
  final String title;
  final String body;
  final String appointmentId;
  final DateTime createdAt;
  bool isRead;

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
