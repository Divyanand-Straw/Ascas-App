
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/locale_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await LocaleService.load();
  runApp(const ThaaiSeyazhiApp());
}
