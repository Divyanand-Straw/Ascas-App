import 'dart:async';

import 'package:app/core/network/api_client.dart';
import 'package:app/features/auth/data/models/auth_models.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/presentation/patient_type_screen.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:app/features/onboarding/presentation/welcome_screen.dart';
import 'package:app/features/splash/presentation/splash_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledAuthRepository extends AuthRepository {
  factory _ControlledAuthRepository(Future<bool> restoreFuture) {
    final apiClient = ApiClient(baseUrl: 'https://unit.test/api/v1');
    return _ControlledAuthRepository._(restoreFuture, apiClient);
  }

  _ControlledAuthRepository._(this._restoreFuture, this.apiClient)
    : super(apiClient: apiClient);

  final Future<bool> _restoreFuture;
  final ApiClient apiClient;

  @override
  Future<bool> restoreSession() => _restoreFuture;

  void dispose() {
    sessionNotifier.dispose();
    isAuthenticatedNotifier.dispose();
    isSuspendedNotifier.dispose();
    apiClient.dio.close(force: true);
  }
}

AuthSession _authenticatedSession() => AuthSession(
  user: AuthUser(
    id: 'patient-user-id',
    phone: '+919876543210',
    email: 'patient@example.com',
    role: 'PATIENT',
    status: 'ACTIVE',
  ),
  profile: PatientProfileData(
    id: 'patient-profile-id',
    userId: 'patient-user-id',
    firstName: 'Patient',
    lastName: 'Name',
    preferredLanguage: 'en',
    linkingStatus: 'UNLINKED',
  ),
  tokens: AuthTokens(
    accessToken: 'authenticated-access-token',
    refreshToken: 'authenticated-refresh-token',
    expiresIn: 900,
  ),
  isNewUser: false,
  hasCompletedProfile: true,
);

Widget _app(AuthRepository authRepository) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SplashScreen(authRepository: authRepository),
);

void main() {
  testWidgets('Tap to Continue follows onboarding without a restored session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ControlledAuthRepository(Future.value(false));
    addTearDown(repository.dispose);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TAP TO CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientTypeScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets(
    'a pending session restore cannot override a user-selected onboarding route',
    (WidgetTester tester) async {
      final restoration = Completer<bool>();
      final repository = _ControlledAuthRepository(restoration.future);
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pump();
      await tester.tap(find.text('TAP TO CONTINUE'));
      await tester.pump();
      repository.sessionNotifier.value = _authenticatedSession();
      repository.isAuthenticatedNotifier.value = true;
      restoration.complete(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    },
  );

  testWidgets(
    'auto-opens the dashboard only for a restored authenticated session',
    (WidgetTester tester) async {
      final repository = _ControlledAuthRepository(Future.value(true));
      repository.sessionNotifier.value = _authenticatedSession();
      repository.isAuthenticatedNotifier.value = true;
      addTearDown(repository.dispose);

      await tester.pumpWidget(_app(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );
}
