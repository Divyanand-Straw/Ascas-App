import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../core/services/locale_service.dart';
import '../core/services/biometric_service.dart';
import '../core/widgets/biometric_lock_screen.dart';
import '../l10n/app_localizations.dart';
import '../features/appointments/presentation/appointment_detail_screen.dart';
import '../features/appointments/presentation/data/appointment_data.dart';
import '../features/splash/presentation/splash_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class ThaaiSeyazhiApp extends StatefulWidget {
  const ThaaiSeyazhiApp({super.key});

  @override
  State<ThaaiSeyazhiApp> createState() => _ThaaiSeyazhiAppState();
}

class _ThaaiSeyazhiAppState extends State<ThaaiSeyazhiApp>
    with WidgetsBindingObserver {
  final _biometricService = BiometricService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _biometricService.addListener(_onBiometricChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _biometricService.removeListener(_onBiometricChanged);
    super.dispose();
  }

  void _onBiometricChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_biometricService.handleLifecycleState(state));
  }

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
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (_biometricService.isLocked) const BiometricLockScreen(),
          ],
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
