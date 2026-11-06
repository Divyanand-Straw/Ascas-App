
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/locale_service.dart';
import 'features/appointments/presentation/data/appointment_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppointmentData();
  await NotificationService.instance.initialize();
  await scheduleActiveAppointmentReminders();
  await LocaleService.load();
  runApp(const ThaaiSeyazhiApp());
}
