import 'dart:convert';

import 'package:app/features/auth/presentation/forgot_password/forgot_password_screen.dart';
import 'package:app/features/auth/presentation/forgot_password/forgot_password_otp_screen.dart';
import 'package:app/features/auth/presentation/forgot_password/reset_password_screen.dart';
import 'package:app/features/auth/presentation/app_security_screen.dart';
import 'package:app/features/auth/presentation/consent_privacy_screen.dart';
import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/features/auth/presentation/developer_email_otp_testing_screen.dart';
import 'package:app/features/auth/presentation/email_password_setup_screen.dart';
import 'package:app/features/auth/presentation/new_patient/mobile_registration_screen.dart';
import 'package:app/features/auth/presentation/new_patient/new_patient_otp_screen.dart';
import 'package:app/features/auth/presentation/new_patient/create_login_credentials_screen.dart';
import 'package:app/features/auth/presentation/new_patient/patient_details_screen.dart';
import 'package:app/features/auth/presentation/existing_patient/clinic_record_access_screen.dart';
import 'package:app/features/auth/presentation/patient_type_screen.dart';
import 'package:app/features/auth/presentation/new_patient/profile_confirmation_screen.dart';
import 'package:app/features/auth/data/account_identity_service.dart';
import 'package:app/features/auth/data/models/auth_models.dart'
    hide PatientProfileData;
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/dashboard/presentation/widgets/patient_profile_screen.dart';
import 'package:app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RegistrationStorage implements AuthTokenStorage {
  String? accessToken;
  String? refreshToken;
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
  }) async {}

  @override
  Future<Map<String, dynamic>?> getUserSession() async => null;

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
  }
}

void main() {
  testWidgets(
    'existing patient OTP still requires clinic identity verification',
    (WidgetTester tester) async {
      final storage = _RegistrationStorage();
      final apiClient = ApiClient(
        baseUrl: 'https://test.invalid/api/v1',
        storage: storage,
      );
      final otpVerifyStub = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/auth/otp/verify') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'user': {
                      'id': 'existing-user',
                      'phone': '+919876543210',
                      'role': 'PATIENT',
                      'status': 'ACTIVE',
                    },
                    'profile': null,
                    'tokens': {
                      'accessToken': 'existing-access',
                      'refreshToken': 'existing-refresh',
                      'expiresIn': 900,
                    },
                    'isNewUser': false,
                    'hasCompletedProfile': false,
                  },
                },
              ),
            );
          } else {
            handler.next(options);
          }
        },
      );
      apiClient.dio.interceptors.add(otpVerifyStub);
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() {
        apiClient.dio.interceptors.remove(otpVerifyStub);
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.pumpWidget(
        _localizedApp(
          NewPatientOtpScreen(
            mobileNumber: '9876543210',
            challengeId: 'existing-challenge',
            purpose: OtpPurpose.existingPatient,
            fromExistingPatient: true,
            authRepository: repository,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify OTP'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(ClinicRecordAccessScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new patient registration continues through mobile OTP', (
    WidgetTester tester,
  ) async {
    final apiClient = ApiClient.instance.dio;
    final requestedPurposes = <String>[];
    final otpSendStub = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith('/auth/otp/send')) {
          requestedPurposes.add(
            (options.data as Map<String, dynamic>)['purpose'] as String,
          );
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'challengeId': 'test-challenge',
                  'expiresInSeconds': 300,
                  'retryAfterSeconds': 45,
                },
              },
            ),
          );
        } else {
          handler.next(options);
        }
      },
    );
    apiClient.interceptors.add(otpSendStub);
    addTearDown(() => apiClient.interceptors.remove(otpSendStub));

    await tester.pumpWidget(_localizedApp(const PatientTypeScreen()));

    await tester.tap(find.text('New Patient'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 9'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(MobileRegistrationScreen), findsOneWidget);
    expect(find.text('STEP 2 OF 9'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(NewPatientOtpScreen), findsOneWidget);
    expect(find.text('STEP 3 OF 9'), findsOneWidget);
    expect(requestedPurposes, ['REGISTRATION']);
    expect(find.text('00:45'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'credentials follow verified OTP, normalize email, and preserve the form when navigating back',
    (WidgetTester tester) async {
      final storage = _RegistrationStorage();
      final apiClient = ApiClient(
        baseUrl: 'https://test.invalid/api/v1',
        storage: storage,
      );
      final requests = <RequestOptions>[];
      final registrationStub = InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.path == '/auth/otp/verify') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'user': {
                      'id': 'registration-user',
                      'phone': '+919876543210',
                      'role': 'PATIENT',
                      'status': 'ACTIVE',
                    },
                    'profile': null,
                    'tokens': {
                      'accessToken': 'registration-access',
                      'refreshToken': 'registration-refresh',
                      'expiresIn': 900,
                    },
                    'isNewUser': true,
                    'hasCompletedProfile': false,
                  },
                },
              ),
            );
          } else if (options.path ==
              '/auth/email/password/registration-setup') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': null},
              ),
            );
          } else {
            handler.next(options);
          }
        },
      );
      apiClient.dio.interceptors.add(registrationStub);
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() {
        apiClient.dio.interceptors.remove(registrationStub);
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.runAsync(
        () => repository.verifyOtp(
          challengeId: 'registration-challenge',
          phone: '9876543210',
          purpose: OtpPurpose.registration,
          otp: '123456',
        ),
      );
      final draft = NewPatientCredentialsDraft();
      await tester.pumpWidget(
        _localizedApp(
          CreateLoginCredentialsScreen(
            mobileNumber: '9876543210',
            draft: draft,
            authRepository: repository,
          ),
        ),
      );
      expect(find.text('STEP 4 OF 9'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email address.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('new-patient-credential-email')),
        ' New.Patient@Example.COM ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-patient-credential-password')),
        'SecurePassword1234',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-patient-credential-confirm-password')),
        'SecurePassword1234',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(PatientDetailsScreen), findsOneWidget);
      expect(find.text('STEP 5 OF 9'), findsOneWidget);
      expect(find.text('Gender'), findsNothing);
      expect(repository.currentSession?.user.email, 'new.patient@example.com');
      final setupRequest = requests.last;
      expect(setupRequest.path, '/auth/email/password/registration-setup');
      expect(setupRequest.data, {
        'email': 'new.patient@example.com',
        'password': 'SecurePassword1234',
      });
      expect(
        jsonEncode(storage.pendingRegistration),
        isNot(contains('SecurePassword1234')),
      );
      expect(
        find.byKey(const ValueKey('new-patient-credential-email')),
        findsNothing,
      );

      Navigator.of(tester.element(find.byType(PatientDetailsScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CreateLoginCredentialsScreen), findsOneWidget);
      expect(find.text('Login credentials saved.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('new-patient-credential-email')),
            )
            .controller!
            .text,
        'new.patient@example.com',
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(PatientDetailsScreen), findsOneWidget);
      expect(
        requests.where(
          (request) =>
              request.path == '/auth/email/password/registration-setup',
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'new patient details forward the emergency contact without adding a gender field',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _localizedApp(
          const PatientDetailsScreen(
            mobileNumber: '9876543210',
            email: 'patient@example.com',
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Priya Sharma');
      tester.widget<TextFormField>(fields.at(1)).controller!.text =
          '15/06/1994';
      await tester.enterText(fields.at(2), '9123456789');
      await tester.pump();

      final reviewButton = find.text('Review profile');
      await tester.ensureVisible(reviewButton);
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      final confirmation = tester.widget<ProfileConfirmationScreen>(
        find.byType(ProfileConfirmationScreen),
      );
      expect(confirmation.emergencyContact, '+919123456789');
      expect(find.text('Gender'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OTP request network and response failures are shown without navigating',
    (WidgetTester tester) async {
      final storage = _RegistrationStorage();
      final apiClient = ApiClient(
        baseUrl: 'http://10.0.2.2:5000/api/v1',
        storage: storage,
      );
      var requestCount = 0;
      final networkStub = InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          if (requestCount == 1) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          } else if (requestCount == 2) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              ),
            );
          } else if (requestCount == 3) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 503,
                  data: 'unavailable',
                ),
              ),
            );
          } else {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'unexpected': true},
              ),
            );
          }
        },
      );
      apiClient.dio.interceptors.add(networkStub);
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() {
        apiClient.dio.interceptors.remove(networkStub);
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.pumpWidget(
        _localizedApp(
          MobileRegistrationScreen(
            patientType: 'New Patient',
            authRepository: repository,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(MobileRegistrationScreen), findsOneWidget);
      expect(find.byType(NewPatientOtpScreen), findsNothing);
      expect(
        find.text('Unable to reach the server. Please verify your connection.'),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(MobileRegistrationScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Connection timed out. Please check your internet connection.',
        ),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(MobileRegistrationScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('The server returned an error (HTTP 503). Please try again.'),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(MobileRegistrationScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The server returned an invalid response while requesting a verification code. Please try again.',
        ),
        findsOneWidget,
      );
      expect(requestCount, 4);
    },
  );

  testWidgets(
    'registration stays on OTP after a failed verification and opens credentials after success',
    (WidgetTester tester) async {
      final storage = _RegistrationStorage();
      final apiClient = ApiClient(
        baseUrl: 'http://10.0.2.2:5000/api/v1',
        storage: storage,
      );
      var verificationRequests = 0;
      final registrationStub = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/auth/otp/send') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'challengeId': 'registration-challenge',
                    'expiresInSeconds': 300,
                    'retryAfterSeconds': 45,
                  },
                },
              ),
            );
          } else if (options.path == '/auth/otp/verify') {
            verificationRequests++;
            if (verificationRequests == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 401,
                    data: {
                      'success': false,
                      'errorCode': 'INVALID_OTP',
                      'message': 'Incorrect verification code.',
                    },
                  ),
                ),
              );
            } else {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': {
                      'user': {
                        'id': 'registration-user',
                        'phone': '+919876543210',
                        'role': 'PATIENT',
                        'status': 'ACTIVE',
                      },
                      'profile': null,
                      'tokens': {
                        'accessToken': 'registration-access',
                        'refreshToken': 'registration-refresh',
                        'expiresIn': 900,
                      },
                      'isNewUser': true,
                      'hasCompletedProfile': false,
                    },
                  },
                ),
              );
            }
          } else if (options.path ==
              '/auth/email/password/registration-setup') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': null},
              ),
            );
          } else {
            handler.next(options);
          }
        },
      );
      apiClient.dio.interceptors.add(registrationStub);
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() {
        apiClient.dio.interceptors.remove(registrationStub);
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.pumpWidget(
        _localizedApp(
          MobileRegistrationScreen(
            patientType: 'New Patient',
            authRepository: repository,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(NewPatientOtpScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify OTP'));
      await tester.pumpAndSettle();
      expect(find.byType(NewPatientOtpScreen), findsOneWidget);
      expect(find.byType(CreateLoginCredentialsScreen), findsNothing);
      expect(
        find.text('Incorrect verification code. Please try again.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify OTP'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateLoginCredentialsScreen), findsOneWidget);
      expect(repository.isAuthenticated, isTrue);
      expect(repository.currentSession?.user.id, 'registration-user');
      expect(storage.accessToken, 'registration-access');
      expect(storage.refreshToken, 'registration-refresh');
      expect(storage.pendingRegistration?['step'], 'credentials');

      await tester.enterText(
        find.byKey(const ValueKey('new-patient-credential-email')),
        ' New.Patient@Example.COM ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-patient-credential-password')),
        'SecurePassword1234',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-patient-credential-confirm-password')),
        'SecurePassword1234',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(PatientDetailsScreen), findsOneWidget);
      expect(find.text('STEP 5 OF 9'), findsOneWidget);
      expect(find.byType(EmailPasswordSetupScreen), findsNothing);
      expect(repository.currentSession?.user.email, 'new.patient@example.com');
      final patientDetails = tester.widget<PatientDetailsScreen>(
        find.byType(PatientDetailsScreen),
      );
      expect(patientDetails.mobileNumber, '9876543210');
      expect(patientDetails.email, 'new.patient@example.com');
      expect(storage.pendingRegistration?['step'], 'patientDetails');

      Navigator.of(tester.element(find.byType(PatientDetailsScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CreateLoginCredentialsScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('new-patient-credential-email')),
            )
            .controller!
            .text,
        'new.patient@example.com',
      );

      Navigator.of(tester.element(find.byType(CreateLoginCredentialsScreen)))
          .pop();
      await tester.pumpAndSettle();
      expect(find.byType(NewPatientOtpScreen), findsOneWidget);
      expect(find.byType(CreateLoginCredentialsScreen), findsNothing);
    },
  );

  testWidgets(
    'shows a sanitized message and stays on OTP when verification has a database failure',
    (WidgetTester tester) async {
      final storage = _RegistrationStorage();
      final apiClient = ApiClient(
        baseUrl: 'http://10.0.2.2:5000/api/v1',
        storage: storage,
      );
      final databaseFailureStub = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/auth/otp/verify') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 503,
                  data: {
                    'success': false,
                    'errorCode': 'DATABASE_SCHEMA_OUT_OF_DATE',
                    'message': 'The request could not be completed. Please try again later.',
                  },
                ),
              ),
            );
          } else {
            handler.next(options);
          }
        },
      );
      apiClient.dio.interceptors.add(databaseFailureStub);
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() {
        apiClient.dio.interceptors.remove(databaseFailureStub);
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
      });

      await tester.pumpWidget(
        _localizedApp(
          NewPatientOtpScreen(
            mobileNumber: '9876543210',
            challengeId: 'registration-challenge',
            purpose: OtpPurpose.registration,
            authRepository: repository,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify OTP'));
      await tester.pumpAndSettle();

      expect(find.byType(NewPatientOtpScreen), findsOneWidget);
      expect(find.byType(CreateLoginCredentialsScreen), findsNothing);
      expect(
        find.text(
          'Verification is temporarily unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('DatabaseError'), findsNothing);
    },
  );

  testWidgets(
    'switching Existing Patient and New Patient on one phone uses separate OTP purposes and cooldown responses',
    (WidgetTester tester) async {
      final apiClient = ApiClient.instance.dio;
      final requestedPurposes = <String>[];
      var challengeCount = 0;
      final otpSendStub = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/auth/otp/send')) {
            requestedPurposes.add(
              (options.data as Map<String, dynamic>)['purpose'] as String,
            );
            challengeCount++;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'challengeId': 'switch-challenge-$challengeCount',
                    'expiresInSeconds': 300,
                    'retryAfterSeconds': 45,
                  },
                },
              ),
            );
          } else {
            handler.next(options);
          }
        },
      );
      apiClient.interceptors.add(otpSendStub);
      addTearDown(() => apiClient.interceptors.remove(otpSendStub));

      await tester.pumpWidget(_localizedApp(const PatientTypeScreen()));
      await tester.tap(find.text('Existing Thaai Seyali Patient'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 1 OF 8'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 2 OF 8'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final existingOtpScreen = tester.widget<NewPatientOtpScreen>(
        find.byType(NewPatientOtpScreen),
      );
      expect(existingOtpScreen.purpose, OtpPurpose.existingPatient);
      expect(existingOtpScreen.fromExistingPatient, isTrue);
      expect(find.text('STEP 3 OF 8'), findsOneWidget);
      expect(find.text('00:45'), findsOneWidget);

      Navigator.of(tester.element(find.byType(NewPatientOtpScreen))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(MobileRegistrationScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final registrationOtpScreen = tester.widget<NewPatientOtpScreen>(
        find.byType(NewPatientOtpScreen),
      );
      expect(registrationOtpScreen.purpose, OtpPurpose.registration);
      expect(find.text('00:45'), findsOneWidget);
      expect(requestedPurposes, ['EXISTING_PATIENT', 'REGISTRATION']);
    },
  );

  testWidgets('profile confirmation keeps email on one line', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const email = 'jforjeevesh77@gmail.com';

    await tester.pumpWidget(
      _localizedApp(
        const ProfileConfirmationScreen(
          fullName: 'Patient Name',
          dateOfBirth: '02/04/1994',
          mobileNumber: '9876543210',
          email: email,
          preferredLanguage: 'English',
        ),
      ),
    );

    final emailText = find.text(email);
    final emailWidget = tester.widget<Text>(emailText);
    expect(emailWidget.maxLines, 1);
    expect(emailWidget.softWrap, isFalse);
    expect(tester.getSize(emailText).height, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new patient email carries through consent to app security', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        const ProfileConfirmationScreen(
          fullName: 'Patient Name',
          dateOfBirth: '02/04/1994',
          mobileNumber: '9876543210',
          email: 'patient@example.com',
          preferredLanguage: 'English',
          gender: 'Female',
        ),
      ),
    );
    expect(find.text('STEP 6 OF 9'), findsOneWidget);
    final confirmButton = find.text('Yes, this is me');
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentPrivacyScreen), findsOneWidget);
    expect(find.text('STEP 7 OF 9'), findsOneWidget);

    final consent = find.byType(Checkbox);
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pump();
    final continueButton = find.text('Accept and continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppSecurityScreen>(find.byType(AppSecurityScreen)).email,
      'patient@example.com',
    );
    expect(find.text('STEP 8 OF 9'), findsOneWidget);
  });

  testWidgets('forgot password opens email recovery from login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_loginApp());

    expect(find.text('Google'), findsNothing);
    expect(find.text('Apple'), findsNothing);
    expect(find.text('Developer Email OTP Testing'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.ensureVisible(find.text('Developer Email OTP Testing'));
    await tester.tap(find.text('Developer Email OTP Testing'));
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperEmailOtpTestingScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(DeveloperEmailOtpTestingScreen)))
        .pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forgot-password-mobile-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forgot-password-email-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forgot-password-send-otp')),
      findsOneWidget,
    );
  });

  testWidgets(
    'email OTP recovery validates contacts, resends, and routes after verification',
    (WidgetTester tester) async {
      final requestedContacts = <(String, String)>[];
      final verifiedOtps = <String>[];
      final verifiedChallenges = <String>[];
      var challengeCount = 0;
      Future<SendEmailOtpResponse> requestOtp(
        String phone,
        String email,
      ) async {
        requestedContacts.add((phone, email));
        challengeCount++;
        return SendEmailOtpResponse(
          challengeId: 'challenge-$challengeCount',
          expiresInSeconds: 300,
          retryAfterSeconds: 30,
        );
      }

      Future<VerifyEmailOtpResponse> verifyOtp(
        String challengeId,
        String email,
        String otp,
      ) async {
        verifiedOtps.add(otp);
        verifiedChallenges.add(challengeId);
        if (otp == '000000') {
          throw Exception('Incorrect OTP. Please try again.');
        }
        if (otp == '111111') {
          throw Exception('OTP has expired. Please request a new OTP.');
        }
        return const PasswordResetOtpVerificationResponse(
          resetGrant: 'reset-grant',
          expiresInSeconds: 600,
        );
      }

      await tester.pumpWidget(
        _localizedApp(
          ForgotPasswordScreen(requestOtp: requestOtp, verifyOtp: verifyOtp),
        ),
      );
      final mobileField = find.byKey(
        const ValueKey('forgot-password-mobile-field'),
      );
      final emailField = find.byKey(
        const ValueKey('forgot-password-email-field'),
      );
      final sendOtp = find.byKey(const ValueKey('forgot-password-send-otp'));
      expect(tester.widget<ElevatedButton>(sendOtp).onPressed, isNull);
      await tester.enterText(mobileField, '123');
      await tester.pump();
      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(sendOtp).onPressed, isNull);
      await tester.enterText(mobileField, '9876543210');
      await tester.pump();
      await tester.enterText(emailField, 'not-an-email');
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(sendOtp).onPressed, isNull);
      await tester.enterText(emailField, 'patient@example.com');
      await tester.pump();
      await tester.ensureVisible(sendOtp);
      await tester.tap(sendOtp);
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordOtpScreen), findsOneWidget);
      expect(find.text('patient@example.com'), findsOneWidget);
      expect(find.text('Enter the six-digit code sent to:'), findsOneWidget);
      expect(find.text('Resend OTP in 30s'), findsOneWidget);
      expect(requestedContacts, [('9876543210', 'patient@example.com')]);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.text('Resend OTP'), findsOneWidget);
      await tester.ensureVisible(find.text('Resend OTP'));
      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();
      expect(requestedContacts, [
        ('9876543210', 'patient@example.com'),
        ('9876543210', 'patient@example.com'),
      ]);
      expect(find.text('Resend OTP in 30s'), findsOneWidget);

      final firstOtpField = find.byKey(const ValueKey('forgot-password-otp-0'));
      final verifyButton = find.text('Verify OTP');
      await tester.enterText(firstOtpField, '000000');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(find.text('Incorrect OTP. Please try again.'), findsOneWidget);

      await tester.enterText(firstOtpField, '111111');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(
        find.text('OTP has expired. Please request a new OTP.'),
        findsOneWidget,
      );

      await tester.enterText(firstOtpField, '123456');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordOtpScreen), findsNothing);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(
        tester
            .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
            .resetAuthorizationToken,
        'reset-grant',
      );
      expect(verifiedOtps, ['000000', '111111', '123456']);
      expect(verifiedChallenges, ['challenge-2', 'challenge-2', 'challenge-2']);
    },
  );

  testWidgets(
    'reset password validates input and remains blocked without backend authorization',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _localizedApp(
          const ResetPasswordScreen(registeredEmail: 'patient@example.com'),
        ),
      );
      final resetButton = find.byKey(const ValueKey('reset-password-submit'));
      await tester.enterText(
        find.byKey(const ValueKey('reset-new-password-field')),
        'short',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password-field')),
        'short',
      );
      await tester.pump();
      expect(find.text('Weak'), findsOneWidget);
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Password must contain at least 12 characters.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));

      await tester.enterText(
        find.byKey(const ValueKey('reset-new-password-field')),
        'NewPassword123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password-field')),
        'DifferentPassword123',
      );
      await tester.pump();
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsWidgets);
      await tester.pump(const Duration(seconds: 5));

      await tester.enterText(
        find.byKey(const ValueKey('reset-new-password-field')),
        'NewPassword123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password-field')),
        'NewPassword123',
      );
      await tester.pump();
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('We could not update your password right now'),
        findsOneWidget,
      );
    },
  );

  testWidgets('password update failure remains on reset screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        ResetPasswordScreen(
          registeredEmail: 'patient@example.com',
          resetAuthorizationToken: 'single-use-token',
          resetPassword: (_, _) async {
            throw Exception('Backend rejected password update.');
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-new-password-field')),
      'SecurePass123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-password-field')),
      'SecurePass123!',
    );
    await tester.pump();
    final resetButton = find.byKey(const ValueKey('reset-password-submit'));
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.text('Backend rejected password update.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('successful password update clears recovery stack to Login', (
    WidgetTester tester,
  ) async {
    String? submittedToken;
    String? submittedPassword;
    await tester.pumpWidget(
      _localizedApp(
        ResetPasswordScreen(
          registeredEmail: 'patient@example.com',
          resetAuthorizationToken: 'single-use-token',
          resetPassword: (token, password) async {
            submittedToken = token;
            submittedPassword = password;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-new-password-field')),
      'SecurePass123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-password-field')),
      'SecurePass123!',
    );
    await tester.pump();
    final resetButton = find.byKey(const ValueKey('reset-password-submit'));
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(submittedToken, 'single-use-token');
    expect(submittedPassword, 'SecurePass123!');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(
      find.textContaining('Your password has been updated successfully'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('changed email is saved only after OTP verification', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = AccountIdentityService();
    final identity = await accounts.createOrGetNewPatient(
      mobileNumber: '9876543210',
      fullName: 'Patient Name',
      dateOfBirth: '02/04/1994',
      preferredLanguage: 'English',
      email: 'old@example.com',
    );
    final requestedEmails = <String>[];
    await tester.pumpWidget(
      _personalDetailsLauncher(
        identity: identity,
        requestOtp: (email) async {
          requestedEmails.add(email);
          return SendEmailOtpResponse(
            challengeId: 'email-change-challenge',
            expiresInSeconds: 300,
            retryAfterSeconds: 30,
          );
        },
        verifyOtp: (challengeId, email, otp) async {
          if (otp == '000000') throw Exception('Incorrect OTP');
          if (otp == '111111') {
            throw Exception('OTP has expired. Please request a new OTP.');
          }
          return EmailChangeOtpVerificationResponse(
            email: normalizeEmail(email),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-personal-details')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('personal-details-update')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-name')),
      'Updated Patient',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-email')),
      'New@Example.COM',
    );
    await tester.tap(find.byKey(const ValueKey('personal-details-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('change-email-verify-otp')),
      findsOneWidget,
    );
    expect(
      (await accounts.accountForId(identity.accountId))?.email,
      'old@example.com',
    );

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('change-email-otp-$i')), '0');
    }
    await tester.tap(find.byKey(const ValueKey('change-email-verify-otp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Incorrect OTP'), findsOneWidget);
    expect(
      (await accounts.accountForId(identity.accountId))?.email,
      'old@example.com',
    );

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('change-email-otp-$i')), '1');
    }
    await tester.tap(find.byKey(const ValueKey('change-email-verify-otp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('OTP has expired. Please request a new OTP.'),
      findsOneWidget,
    );
    expect(
      (await accounts.accountForId(identity.accountId))?.email,
      'old@example.com',
    );

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('change-email-otp-$i')), '2');
    }
    await tester.tap(find.byKey(const ValueKey('change-email-verify-otp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final saved = await accounts.accountForId(identity.accountId);
    expect(saved?.fullName, 'Updated Patient');
    expect(saved?.email, 'new@example.com');
    expect(requestedEmails, ['new@example.com']);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('new@example.com'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancelling email verification keeps the saved email unchanged', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = AccountIdentityService();
    final identity = await accounts.createOrGetNewPatient(
      mobileNumber: '9876543210',
      fullName: 'Patient Name',
      dateOfBirth: '02/04/1994',
      preferredLanguage: 'English',
      email: 'old@example.com',
    );
    var requestedEmail = '';
    var verifyCalled = false;
    await tester.pumpWidget(
      _personalDetailsLauncher(
        identity: identity,
        requestOtp: (email) async {
          requestedEmail = email;
          return const SendEmailOtpResponse(
            challengeId: 'email-change-challenge',
            expiresInSeconds: 300,
            retryAfterSeconds: 30,
          );
        },
        verifyOtp: (challengeId, email, otp) async {
          verifyCalled = true;
          return EmailChangeOtpVerificationResponse(
            email: normalizeEmail(email),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-personal-details')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('personal-details-update')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('personal-details-email')),
      'new@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('personal-details-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('change-email-verify-otp')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(verifyCalled, isFalse);
    expect(requestedEmail, 'new@example.com');
    expect(
      (await accounts.accountForId(identity.accountId))?.email,
      'old@example.com',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'email change refreshes the authenticated account without a local record',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final accounts = AccountIdentityService();
      final identity = await accounts.createOrGetNewPatient(
        mobileNumber: '9876543210',
        fullName: 'Patient Name',
        dateOfBirth: '02/04/1994',
        preferredLanguage: 'English',
        email: 'old@example.com',
      );
      final refreshedProfiles = <PatientProfileData>[];
      var updateProfileCalls = 0;
      var refreshSessionCalls = 0;
      await tester.pumpWidget(
        _personalDetailsLauncher(
          identity: identity,
          accountId: 'authenticated-user-id',
          requestOtp: (email) async => const SendEmailOtpResponse(
            challengeId: 'email-change-challenge',
            expiresInSeconds: 300,
            retryAfterSeconds: 30,
          ),
          verifyOtp: (challengeId, email, otp) async {
            expect(challengeId, 'email-change-challenge');
            expect(email, 'new@example.com');
            expect(otp, '222222');
            return EmailChangeOtpVerificationResponse(
              email: normalizeEmail(email),
            );
          },
          updateProfile:
              ({
                required String firstName,
                required String lastName,
                required String dateOfBirth,
                String? gender,
                required String preferredLanguage,
              }) async {
                updateProfileCalls++;
              },
          refreshSession: () async {
            refreshSessionCalls++;
            return AuthSession(
              user: AuthUser(
                id: 'authenticated-user-id',
                phone: '+919876543210',
                email: 'new@example.com',
                role: 'PATIENT',
                status: 'ACTIVE',
              ),
              tokens: AuthTokens(
                accessToken: 'access-token',
                refreshToken: 'refresh-token',
                expiresIn: 900,
              ),
              isNewUser: false,
              hasCompletedProfile: true,
            );
          },
          onProfileUpdated: refreshedProfiles.add,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-personal-details')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('personal-details-update')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('personal-details-email')),
        'New@Example.COM',
      );
      await tester.tap(find.byKey(const ValueKey('personal-details-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      for (var i = 0; i < 6; i++) {
        await tester.enterText(
          find.byKey(ValueKey('change-email-otp-$i')),
          '2',
        );
      }
      await tester.tap(find.byKey(const ValueKey('change-email-verify-otp')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(updateProfileCalls, 1);
      expect(refreshSessionCalls, 1);
      expect(
        (await accounts.accountForId(identity.accountId))?.email,
        'old@example.com',
      );
      expect(refreshedProfiles.single.email, 'new@example.com');
      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.text('The account could not be found.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Widget _personalDetailsLauncher({
  required AccountIdentity identity,
  String? accountId,
  required Future<SendEmailOtpResponse> Function(String email) requestOtp,
  required Future<VerifyEmailOtpResponse> Function(
    String challengeId,
    String email,
    String otp,
  )
  verifyOtp,
  Future<void> Function({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    String? gender,
    required String preferredLanguage,
  })?
  updateProfile,
  Future<AuthSession> Function()? refreshSession,
  ValueChanged<PatientProfileData>? onProfileUpdated,
}) => _localizedApp(
  Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('open-personal-details'),
          onPressed: () => Navigator.push<PatientProfileData>(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalDetailsScreen(
                name: identity.fullName,
                mobile: identity.mobileNumber,
                email: identity.email,
                dateOfBirth: identity.dateOfBirth,
                language: identity.preferredLanguage,
                accountId: accountId ?? identity.accountId,
                requestOtp: requestOtp,
                verifyOtp: verifyOtp,
                updateProfile: updateProfile,
                refreshSession: refreshSession,
                onProfileUpdated: onProfileUpdated,
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Widget _loginApp() => _localizedApp(const LoginScreen());

Widget _localizedApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
