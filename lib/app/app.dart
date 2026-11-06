
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../core/services/locale_service.dart';
import '../l10n/app_localizations.dart';
import '../features/appointments/presentation/appointment_detail_screen.dart';
import '../features/appointments/presentation/data/appointment_data.dart';
import '../features/splash/presentation/splash_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class ThaaiSeyazhiApp extends StatelessWidget {
  const ThaaiSeyazhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    NotificationService.instance.onAppointmentNotificationTap = (reference) {
      final appointment = findAppointmentById(reference);
      if (appointment == null) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AppointmentDetailsScreen(appointment: appointment),
        ),
      );
    };
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService.locale,
      builder: (context, locale, child) => MaterialApp(
        navigatorKey: navigatorKey,
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SplashScreen(),
      ),
    );
  }
}
