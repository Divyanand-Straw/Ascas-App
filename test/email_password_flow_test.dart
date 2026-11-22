import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/presentation/existing_patient/clinic_record_access_screen.dart';
import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/features/auth/presentation/registration_complete_screen.dart';
import 'package:app/features/auth/presentation/new_patient/create_login_credentials_screen.dart';
import 'package:app/features/auth/presentation/new_patient/patient_details_screen.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/features/auth/data/models/auth_models.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryAuthStorage implements AuthTokenStorage {
  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? userSession;
  Map<String, String>? pendingRegistration;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveUserSession({
    required String userId,
    required String phone,
    required String role,
    required bool hasCompletedProfile,
  }) async {
    userSession = {'userId': userId, 'phone': phone, 'role': role};
  }

  @override
  Future<Map<String, dynamic>?> getUserSession() async => userSession;

  @override
  Future<void> savePendingRegistration({
    required String userId,
    required String step,
    required String email,
  }) async {
    pendingRegistration = {'userId': userId, 'step': step, 'email': email};
  }

  @override
  Future<Map<String, String>?> getPendingRegistration() async =>
      pendingRegistration;

  @override
  Future<void> clearPendingRegistration() async {
    pendingRegistration = null;
  }

  @override
  Future<void> clearAll() async {
    accessToken = null;
    refreshToken = null;
    userSession = null;
  }
}

class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MobileLoginAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final responseData = options.path == '/auth/otp/send'
        ? {
            'challengeId': 'login-challenge',
            'expiresInSeconds': 300,
            'retryAfterSeconds': 45,
          }
        : {
            'user': {
              'id': 'user-1',
              'phone': '+919876543210',
              'email': 'patient@example.com',
              'role': 'PATIENT',
              'status': 'ACTIVE',
            },
            'profile': {
              'id': 'profile-1',
              'userId': 'user-1',
              'firstName': 'Existing',
              'lastName': 'Patient',
              'dob': '1990-01-02',
              'clinicMrn': 'MRN-1001',
              'preferredLanguage': 'en',
              'linkingStatus': 'LINKED',
            },
            'tokens': {
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'expiresIn': 900,
            },
            'isNewUser': false,
            'hasCompletedProfile': true,
          };
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': responseData}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DeferredProfileSaveAdapter implements HttpClientAdapter {
  final completer = Completer<ResponseBody>();
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    request = options;
    return completer.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'mobile OTP login opens dashboard instead of registration or clinic linking',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryAuthStorage()
        ..pendingRegistration = {
          'userId': 'user-1',
          'step': 'credentials',
          'email': '',
        };
      final apiClient = ApiClient(
        baseUrl: 'https://test.invalid/api/v1',
        storage: storage,
      );
      final adapter = _MobileLoginAdapter();
      apiClient.dio.httpClientAdapter = adapter;
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() {
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.pumpWidget(_app(LoginScreen(authRepository: repository)));
      await tester.enterText(
        find.byKey(const ValueKey('login-mobile-field')),
        '9876543210',
      );
      await tester.tap(find.text('Get OTP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify and proceed'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(adapter.requests.map((request) => request.path), [
        '/auth/otp/send',
        '/auth/otp/verify',
      ]);
      expect(
        (adapter.requests.first.data as Map<String, dynamic>)['purpose'],
        'LOGIN',
      );
      expect(
        (adapter.requests.last.data as Map<String, dynamic>)['purpose'],
        'LOGIN',
      );
      expect(repository.isAuthenticated, isTrue);
      expect(repository.currentSession?.user.id, 'user-1');
      expect(repository.currentSession?.user.email, 'patient@example.com');
      expect(find.byType(DashboardScreen), findsOneWidget);
      final dashboard = tester.widget<DashboardScreen>(
        find.byType(DashboardScreen),
      );
      expect(dashboard.email, 'patient@example.com');
      expect(dashboard.patientName, 'Existing Patient');
      expect(dashboard.mobileNumber, '+919876543210');
      expect(dashboard.patientId, 'MRN-1001');
      expect(dashboard.dateOfBirth, '1990-01-02');
      expect(find.text('STEP 3 OF 8'), findsNothing);
      expect(find.byType(ClinicRecordAccessScreen), findsNothing);
      expect(find.byType(CreateLoginCredentialsScreen), findsNothing);
      expect(find.byType(PatientDetailsScreen), findsNothing);
      expect(find.byType(RegistrationCompleteScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'password login persists the shared session and opens dashboard',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryAuthStorage()
        ..pendingRegistration = {
          'userId': 'user-1',
          'step': 'credentials',
          'email': '',
        };
      final apiClient = ApiClient(
        baseUrl: 'https://test.invalid/api/v1',
        storage: storage,
      );
      final adapter = _LoginAdapter(200, {
        'success': true,
        'data': {
          'user': {
            'id': 'user-1',
            'phone': '+919876543210',
            'email': 'patient@example.com',
            'role': 'PATIENT',
            'status': 'ACTIVE',
          },
          'profile': {
            'id': 'profile-1',
            'userId': 'user-1',
            'firstName': 'Existing',
            'lastName': 'Patient',
            'dob': '1990-01-02',
            'clinicMrn': 'MRN-1001',
            'preferredLanguage': 'en',
            'linkingStatus': 'LINKED',
          },
          'tokens': {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 900,
          },
          'isNewUser': false,
          'hasCompletedProfile': true,
        },
      });
      apiClient.dio.httpClientAdapter = adapter;
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() {
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.pumpWidget(_app(LoginScreen(authRepository: repository)));
      expect(find.byKey(const ValueKey('login-mobile-field')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('login-method-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email-field')),
        ' Patient@Example.COM ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password-field')),
        'SecurePassword123',
      );
      bool passwordIsObscured() => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('login-password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText;

      expect(passwordIsObscured(), isTrue);
      await tester.tap(
        find.byKey(const ValueKey('login-password-visibility-toggle')),
      );
      await tester.pump();
      expect(passwordIsObscured(), isFalse);
      await tester.tap(
        find.byKey(const ValueKey('login-password-visibility-toggle')),
      );
      await tester.pump();
      expect(passwordIsObscured(), isTrue);
      await tester.tap(find.text('Log in'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(adapter.request?.path, '/auth/email/password/login');
      expect(adapter.request?.data, {
        'email': 'patient@example.com',
        'password': 'SecurePassword123',
      });
      expect(adapter.request?.headers.containsKey('Authorization'), isFalse);
      expect(storage.accessToken, 'access-token');
      expect(storage.refreshToken, 'refresh-token');
      expect(repository.isAuthenticated, isTrue);
      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(
        tester.widget<DashboardScreen>(find.byType(DashboardScreen)).email,
        'patient@example.com',
      );
      final dashboard = tester.widget<DashboardScreen>(
        find.byType(DashboardScreen),
      );
      expect(dashboard.patientName, 'Existing Patient');
      expect(dashboard.mobileNumber, '+919876543210');
      expect(dashboard.dateOfBirth, '1990-01-02');
    },
  );

  testWidgets('password login shows backend authentication failure', (
    WidgetTester tester,
  ) async {
    final storage = _MemoryAuthStorage();
    final apiClient = ApiClient(
      baseUrl: 'https://test.invalid/api/v1',
      storage: storage,
    );
    apiClient.dio.httpClientAdapter = _LoginAdapter(401, {
      'success': false,
      'errorCode': 'INVALID_CREDENTIALS',
      'message': 'Invalid email or password.',
    });
    final repository = AuthRepository(apiClient: apiClient, storage: storage);
    addTearDown(() {
      repository.sessionNotifier.dispose();
      repository.isAuthenticatedNotifier.dispose();
      repository.isSuspendedNotifier.dispose();
      apiClient.dio.close(force: true);
    });

    await tester.pumpWidget(_app(LoginScreen(authRepository: repository)));
    await tester.tap(find.byKey(const ValueKey('login-method-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'patient@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'incorrect-password',
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(storage.accessToken, isNull);
    expect(repository.isAuthenticated, isFalse);
  });

  testWidgets(
    'registration completion waits for successful backend profile persistence',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryAuthStorage()..accessToken = 'access-token';
      final apiClient = ApiClient(
        baseUrl: 'https://test.invalid/api/v1',
        storage: storage,
      );
      final adapter = _DeferredProfileSaveAdapter();
      apiClient.dio.httpClientAdapter = adapter;
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      repository.sessionNotifier.value = AuthSession(
        user: AuthUser(
          id: 'user-1',
          phone: '+919876543210',
          email: 'priya@example.com',
          role: 'PATIENT',
          status: 'ACTIVE',
        ),
        tokens: AuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresIn: 900,
        ),
        isNewUser: true,
        hasCompletedProfile: false,
      );
      addTearDown(() {
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.pumpWidget(
        _app(
          RegistrationCompleteScreen(
            fullName: 'Priya Sharma',
            dateOfBirth: '15/06/1994',
            mobileNumber: '+919876543210',
            email: '',
            emergencyContact: '+919123456789',
            preferredLanguage: 'English',
            authRepository: repository,
          ),
        ),
      );
      await tester.pump();
      for (
        var attempt = 0;
        attempt < 10 && adapter.request == null;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('SAVING REGISTRATION'), findsOneWidget);
      expect(find.text('REGISTRATION COMPLETE'), findsNothing);
      expect(adapter.request?.path, '/auth/profile');
      expect(
        (adapter.request?.data as Map<String, dynamic>)['emergencyContact'],
        '+919123456789',
      );

      adapter.completer.complete(
        ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'profile-1',
              'userId': 'user-1',
              'firstName': 'Priya',
              'lastName': 'Sharma',
              'dob': '1994-06-15',
              'emergencyContact': '+919123456789',
              'preferredLanguage': 'en',
              'linkingStatus': 'UNLINKED',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REGISTRATION COMPLETE'), findsOneWidget);
      expect(find.text('New patient profile created'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('optional-email-password-setup')),
        findsNothing,
      );
    },
  );
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
