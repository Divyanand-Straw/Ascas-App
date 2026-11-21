import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/features/auth/data/models/auth_models.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryAuthStorage implements AuthTokenStorage {
  String? accessToken = 'stored-access-token';
  String? refreshToken = 'stored-refresh-token';
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
    userSession = {
      'userId': userId,
      'phone': phone,
      'role': role,
      'hasCompletedProfile': hasCompletedProfile,
    };
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

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responseForRequest);

  final Map<String, dynamic> Function(RequestOptions options)
  responseForRequest;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responseForRequest(options);
    return ResponseBody.fromString(
      jsonEncode(response['body']),
      response['statusCode'] as int,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _sessionResponse({bool isNewUser = false}) => {
  'statusCode': 200,
  'body': {
    'success': true,
    'data': {
      'user': {
        'id': 'user-1',
        'phone': '+919876543210',
        'email': 'patient@example.com',
        'role': 'PATIENT',
        'status': 'ACTIVE',
      },
      'profile': null,
      'tokens': {
        'accessToken': 'new-access-token',
        'refreshToken': 'new-refresh-token',
        'expiresIn': 900,
      },
      'isNewUser': isNewUser,
      'hasCompletedProfile': false,
    },
  },
};

Future<HttpServer> _startMockAuthServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

Future<void> _respond(
  HttpRequest request,
  int statusCode,
  Map<String, dynamic> body,
) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

void main() {
  group('Mobile OTP purpose model', () {
    test(
      'serializes and parses every explicit mobile authentication purpose',
      () {
        expect(
          [
            OtpPurpose.login,
            OtpPurpose.registration,
            OtpPurpose.existingPatient,
            OtpPurpose.linkedMember,
          ].map(
            (purpose) => SendOtpRequest(
              phone: '+919876543210',
              purpose: purpose,
            ).toJson()['purpose'],
          ),
          ['LOGIN', 'REGISTRATION', 'EXISTING_PATIENT', 'LINKED_MEMBER'],
        );
        expect(
          OtpPurpose.fromApiString('EXISTING_PATIENT'),
          OtpPurpose.existingPatient,
        );
        expect(
          () => OtpPurpose.fromApiString('UNKNOWN'),
          throwsFormatException,
        );
      },
    );

    test('rejects OTP send responses without a valid challenge contract', () {
      expect(
        () => SendOtpResponse.fromJson({
          'expiresInSeconds': 300,
          'retryAfterSeconds': 45,
        }),
        throwsFormatException,
      );
      expect(
        () => SendOtpResponse.fromJson({
          'challengeId': 'challenge-1',
          'expiresInSeconds': 300,
          'retryAfterSeconds': -1,
        }),
        throwsFormatException,
      );
    });
  });

  group('Email and password auth models', () {
    test('serializes normalized email requests and supported purposes', () {
      expect(
        SendEmailOtpRequest(
          email: '  Patient@Example.COM ',
          purpose: EmailOtpPurpose.passwordReset,
        ).toJson(),
        {'email': 'patient@example.com', 'purpose': 'PASSWORD_RESET'},
      );
      expect(
        VerifyEmailOtpRequest(
          challengeId: 'challenge-1',
          email: ' PATIENT@example.com ',
          purpose: EmailOtpPurpose.emailChange,
          otp: '123456',
        ).toJson(),
        {
          'challengeId': 'challenge-1',
          'email': 'patient@example.com',
          'purpose': 'EMAIL_CHANGE',
          'otp': '123456',
        },
      );
      expect(
        SendEmailActivationOtpRequest(email: ' New.Patient@Example.COM ')
            .toJson(),
        {'email': 'new.patient@example.com'},
      );
      expect(
        VerifyEmailActivationOtpRequest(
          challengeId: 'challenge-activation',
          email: ' NEW.PATIENT@example.com ',
          otp: '123456',
        ).toJson(),
        {
          'challengeId': 'challenge-activation',
          'email': 'new.patient@example.com',
          'otp': '123456',
        },
      );
      expect(
        EmailActivationOtpVerificationResponse.fromJson({
          'purpose': 'ACCOUNT_ACTIVATION',
          'verified': true,
        }),
        isA<EmailActivationOtpVerificationResponse>(),
      );
      expect(
        () => EmailActivationOtpVerificationResponse.fromJson({
          'purpose': 'EMAIL_CHANGE',
          'verified': true,
        }),
        throwsFormatException,
      );
      expect(
        () => EmailOtpPurpose.fromApiString('ACCOUNT_ACTIVATION'),
        throwsFormatException,
      );
    });

    test(
      'parses email OTP send and purpose-specific verification responses',
      () {
        final send = SendEmailOtpResponse.fromJson({
          'challengeId': 'challenge-1',
          'expiresInSeconds': 300,
          'retryAfterSeconds': 30,
        });
        expect(send.challengeId, 'challenge-1');
        expect(send.expiresInSeconds, 300);
        expect(send.retryAfterSeconds, 30);

        final reset = VerifyEmailOtpResponse.fromJson({
          'purpose': 'PASSWORD_RESET',
          'verified': true,
          'resetGrant': 'grant-token',
          'expiresInSeconds': 600,
        });
        expect(reset, isA<PasswordResetOtpVerificationResponse>());
        expect(
          (reset as PasswordResetOtpVerificationResponse).resetGrant,
          'grant-token',
        );

        final change = VerifyEmailOtpResponse.fromJson({
          'purpose': 'EMAIL_CHANGE',
          'verified': true,
          'email': 'Patient@Example.COM',
        });
        expect(change, isA<EmailChangeOtpVerificationResponse>());
        expect(
          (change as EmailChangeOtpVerificationResponse).email,
          'patient@example.com',
        );
      },
    );

    test('serializes password request bodies without altering passwords', () {
      expect(
        EmailPasswordLoginRequest(
          email: ' Patient@Example.COM ',
          password: ' case sensitive ',
          deviceInfo: 'Test device',
        ).toJson(),
        {
          'email': 'patient@example.com',
          'password': ' case sensitive ',
          'deviceInfo': 'Test device',
        },
      );
      expect(const SetupPasswordRequest(password: 'new-password').toJson(), {
        'password': 'new-password',
      });
      expect(
        const CompletePasswordResetRequest(
          resetGrant: 'grant',
          newPassword: 'new-password',
        ).toJson(),
        {'resetGrant': 'grant', 'newPassword': 'new-password'},
      );
    });
  });

  group('AuthRepository API integration', () {
    late _MemoryAuthStorage storage;
    late ApiClient apiClient;
    late AuthRepository repository;
    late _RecordingAdapter adapter;

    setUp(() {
      storage = _MemoryAuthStorage();
      apiClient = ApiClient(
        baseUrl: 'https://unit.test/api/v1',
        storage: storage,
      );
      adapter = _RecordingAdapter((options) {
        final body = options.data as Map<String, dynamic>?;
        switch (options.path) {
          case '/auth/email/otp/send':
          case '/auth/email/password/reset/otp/send':
          case '/auth/email/activation/otp/send':
          case '/auth/email/developer-test/otp/send':
            return {
              'statusCode': 200,
              'body': {
                'success': true,
                'data': {
                  'challengeId': 'challenge-1',
                  'expiresInSeconds': 300,
                  'retryAfterSeconds': 30,
                },
              },
            };
          case '/auth/email/activation/otp/verify':
            return {
              'statusCode': 200,
              'body': {
                'success': true,
                'data': {'purpose': 'ACCOUNT_ACTIVATION', 'verified': true},
              },
            };
          case '/auth/email/developer-test/otp/verify':
            return {
              'statusCode': 200,
              'body': {
                'success': true,
                'data': {'purpose': 'DEVELOPER_EMAIL_TEST', 'verified': true},
              },
            };
          case '/auth/email/otp/verify':
            if (body?['purpose'] == 'PASSWORD_RESET') {
              return {
                'statusCode': 200,
                'body': {
                  'success': true,
                  'data': {
                    'purpose': 'PASSWORD_RESET',
                    'verified': true,
                    'resetGrant': 'reset-grant',
                    'expiresInSeconds': 600,
                  },
                },
              };
            }
            return {
              'statusCode': 200,
              'body': {
                'success': true,
                'data': {
                  'purpose': 'EMAIL_CHANGE',
                  'verified': true,
                  'email': 'new@example.com',
                },
              },
            };
          case '/auth/me':
            return {
              'statusCode': 200,
              'body': {
                'success': true,
                'data': {
                  'user': {
                    'id': 'user-1',
                    'phone': '+919876543210',
                    'email': 'new@example.com',
                    'role': 'PATIENT',
                    'status': 'ACTIVE',
                  },
                  'profile': {
                    'id': 'profile-1',
                    'userId': 'user-1',
                    'firstName': 'Priya',
                    'lastName': 'Sharma',
                    'dob': '1994-06-15T00:00:00.000Z',
                    'preferredLanguage': 'en',
                    'linkingStatus': 'UNLINKED',
                  },
                  'hasCompletedProfile': true,
                },
              },
            };
          case '/auth/email/password/login':
            return _sessionResponse();
          case '/auth/profile':
            return {
              'statusCode': 200,
              'body': {
                'success': true,
                'data': {
                  'id': 'profile-1',
                  'userId': 'user-1',
                  'firstName': 'Priya',
                  'lastName': 'Sharma',
                  'dob': '1994-06-15T00:00:00.000Z',
                  'gender': 'Female',
                  'emergencyContact': '+919123456789',
                  'clinicMrn': null,
                  'preferredLanguage': 'ta',
                  'linkingStatus': 'UNLINKED',
                },
              },
            };
          case '/auth/email/password/setup':
          case '/auth/email/password/registration-setup':
          case '/auth/email/password/reset':
            return {
              'statusCode': 200,
              'body': {'success': true, 'message': 'Completed.'},
            };
          case '/auth/logout':
            return {
              'statusCode': 200,
              'body': {'success': true, 'data': null},
            };
          default:
            return {
              'statusCode': 404,
              'body': {
                'success': false,
                'errorCode': 'NOT_FOUND',
                'message': 'Unexpected request.',
              },
            };
        }
      });
      apiClient.dio.httpClientAdapter = adapter;
      repository = AuthRepository(apiClient: apiClient, storage: storage);
    });

    tearDown(() {
      repository.sessionNotifier.dispose();
      repository.isAuthenticatedNotifier.dispose();
      repository.isSuspendedNotifier.dispose();
      apiClient.dio.close(force: true);
    });

    test(
      'sends and verifies reset email OTP without bearer authorization',
      () async {
        final send = await repository.sendPasswordResetOtp(
          phone: '9876543210',
          email: ' Patient@Example.COM ',
        );
        final verify = await repository.verifyEmailOtp(
          challengeId: send.challengeId,
          email: 'PATIENT@example.com',
          purpose: EmailOtpPurpose.passwordReset,
          otp: '123456',
        );

        expect(send.retryAfterSeconds, 30);
        expect(verify, isA<PasswordResetOtpVerificationResponse>());
        expect(
          (verify as PasswordResetOtpVerificationResponse).resetGrant,
          'reset-grant',
        );
        expect(adapter.requests, hasLength(2));
        for (final request in adapter.requests) {
          expect(request.headers.containsKey('Authorization'), isFalse);
        }
        expect(
          adapter.requests.first.path,
          '/auth/email/password/reset/otp/send',
        );
        expect(adapter.requests.first.data, {
          'phone': '+919876543210',
          'email': 'patient@example.com',
        });
      },
    );

    test('sends and verifies email changes with the authenticated session and refreshes the account', () async {
      await repository.loginWithEmailPassword(
        email: 'patient@example.com',
        password: 'secure-password',
      );
      final send = await repository.sendEmailOtp(
        email: ' New@Example.COM ',
        purpose: EmailOtpPurpose.emailChange,
      );
      final verification = await repository.verifyEmailOtp(
        challengeId: send.challengeId,
        email: ' NEW@example.com ',
        purpose: EmailOtpPurpose.emailChange,
        otp: '123456',
      );
      expect(verification, isA<EmailChangeOtpVerificationResponse>());

      final refreshed = await repository.refreshCurrentUser();

      expect(send.challengeId, 'challenge-1');
      expect(adapter.requests, hasLength(4));
      expect(adapter.requests[0].path, '/auth/email/password/login');
      expect(adapter.requests[0].headers.containsKey('Authorization'), isFalse);
      expect(adapter.requests[1].path, '/auth/email/otp/send');
      expect(
        adapter.requests[1].headers['Authorization'],
        'Bearer new-access-token',
      );
      expect(adapter.requests[1].data, {
        'email': 'new@example.com',
        'purpose': 'EMAIL_CHANGE',
      });
      expect(adapter.requests[2].path, '/auth/email/otp/verify');
      expect(
        adapter.requests[2].headers['Authorization'],
        'Bearer new-access-token',
      );
      expect(adapter.requests[2].data, {
        'challengeId': 'challenge-1',
        'email': 'new@example.com',
        'purpose': 'EMAIL_CHANGE',
        'otp': '123456',
      });
      expect(adapter.requests[3].path, '/auth/me');
      expect(
        adapter.requests[3].headers['Authorization'],
        'Bearer new-access-token',
      );
      expect(refreshed.user.id, 'user-1');
      expect(refreshed.user.email, 'new@example.com');
      expect(refreshed.profile?.fullName, 'Priya Sharma');
      expect(repository.currentSession, same(refreshed));
    });

    test(
      'uses the isolated developer email test endpoints without account auth',
      () async {
        final send = await repository.sendDeveloperEmailTestOtp(
          email: ' Test.Recipient@Example.COM ',
        );
        final verify = await repository.verifyDeveloperEmailTestOtp(
          challengeId: send.challengeId,
          email: 'TEST.RECIPIENT@example.com',
          otp: '123456',
        );

        expect(send.retryAfterSeconds, 30);
        expect(verify, isA<DeveloperEmailTestOtpVerificationResponse>());
        expect(adapter.requests, hasLength(2));
        expect(adapter.requests[0].path, '/auth/email/developer-test/otp/send');
        expect(adapter.requests[0].data, {
          'email': 'test.recipient@example.com',
        });
        expect(
          adapter.requests[1].path,
          '/auth/email/developer-test/otp/verify',
        );
        expect(adapter.requests[1].data, {
          'challengeId': send.challengeId,
          'email': 'test.recipient@example.com',
          'otp': '123456',
        });
        for (final request in adapter.requests) {
          expect(request.headers.containsKey('Authorization'), isFalse);
        }
      },
    );

    test(
      'saves patient profile through the authenticated account endpoint',
      () async {
        final profile = await repository.savePatientProfile(
          firstName: 'Priya',
          lastName: 'Sharma',
          dateOfBirth: '1994-06-15',
          emergencyContact: '+919123456789',
          gender: 'Female',
          preferredLanguage: 'ta',
        );

        expect(profile.userId, 'user-1');
        expect(profile.gender, 'Female');
        expect(profile.emergencyContact, '+919123456789');
        expect(profile.clinicMrn, isNull);
        expect(adapter.requests, hasLength(1));
        final request = adapter.requests.single;
        expect(request.path, '/auth/profile');
        expect(request.headers['Authorization'], 'Bearer stored-access-token');
        expect(request.data, {
          'firstName': 'Priya',
          'lastName': 'Sharma',
          'dob': '1994-06-15',
          'emergencyContact': '+919123456789',
          'gender': 'Female',
          'preferredLanguage': 'ta',
        });
      },
    );

    test('omits optional gender when saving patient profile', () async {
      await repository.savePatientProfile(
        firstName: 'Priya',
        lastName: 'Sharma',
        dateOfBirth: '1994-06-15',
        emergencyContact: '+919123456789',
        preferredLanguage: 'ta',
      );

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.data, {
        'firstName': 'Priya',
        'lastName': 'Sharma',
        'dob': '1994-06-15',
        'emergencyContact': '+919123456789',
        'preferredLanguage': 'ta',
      });
    });

    test('keeps stale bearer tokens off all mobile OTP requests', () async {
      adapter = _RecordingAdapter((options) {
        if (options.path == '/auth/otp/send') {
          return {
            'statusCode': 200,
            'body': {
              'success': true,
              'data': {
                'challengeId': 'mobile-challenge',
                'expiresInSeconds': 300,
                'retryAfterSeconds': 45,
              },
            },
          };
        }
        if (options.path == '/auth/otp/verify') return _sessionResponse();
        return {
          'statusCode': 404,
          'body': {
            'success': false,
            'errorCode': 'NOT_FOUND',
            'message': 'Unexpected request.',
          },
        };
      });
      apiClient.dio.httpClientAdapter = adapter;
      const purposes = [
        OtpPurpose.registration,
        OtpPurpose.login,
        OtpPurpose.existingPatient,
        OtpPurpose.linkedMember,
      ];
      for (final purpose in purposes) {
        final otpSend = await repository.sendOtp(
          phone: '9876543210',
          purpose: purpose,
        );
        await repository.verifyOtp(
          challengeId: otpSend.challengeId,
          phone: '9876543210',
          purpose: purpose,
          otp: '123456',
        );
      }

      expect(adapter.requests, hasLength(8));
      expect(adapter.requests.map((request) => request.path), [
        '/auth/otp/send',
        '/auth/otp/verify',
        '/auth/otp/send',
        '/auth/otp/verify',
        '/auth/otp/send',
        '/auth/otp/verify',
        '/auth/otp/send',
        '/auth/otp/verify',
      ]);
      for (final request in adapter.requests) {
        expect(request.headers.containsKey('Authorization'), isFalse);
      }
      expect(
        adapter.requests
            .where((request) => request.path.endsWith('/otp/send'))
            .map((request) => (request.data as Map<String, dynamic>)['purpose'])
            .toList(),
        ['REGISTRATION', 'LOGIN', 'EXISTING_PATIENT', 'LINKED_MEMBER'],
      );
    });

    test('persists password-free registration progress around authenticated credentials and profile calls', () async {
      adapter = _RecordingAdapter((options) {
        if (options.path == '/auth/otp/verify') {
          return _sessionResponse(isNewUser: true);
        }
        if (options.path == '/auth/email/password/registration-setup') {
          return {
            'statusCode': 200,
            'body': {'success': true, 'data': null},
          };
        }
        if (options.path == '/auth/profile') {
          return {
            'statusCode': 200,
            'body': {
              'success': true,
              'data': {
                'id': 'profile-1',
                'userId': 'user-1',
                'firstName': 'Priya',
                'lastName': 'Sharma',
                'dob': '1994-06-15',
                'gender': 'Female',
                'preferredLanguage': 'en',
              },
            },
          };
        }
        return {
          'statusCode': 404,
          'body': {
            'success': false,
            'errorCode': 'NOT_FOUND',
            'message': 'Unexpected request.',
          },
        };
      });
      apiClient.dio.httpClientAdapter = adapter;

      await repository.verifyOtp(
        challengeId: 'registration-challenge',
        phone: '9876543210',
        purpose: OtpPurpose.registration,
        otp: '123456',
      );
      expect(
        repository.pendingRegistration?.step,
        PendingRegistrationStep.credentials,
      );

      await repository.setupRegistrationCredentials(
        email: ' New.Patient@Example.COM ',
        password: 'NeverPersistThisPassword123',
      );
      expect(
        adapter.requests[1].path,
        '/auth/email/password/registration-setup',
      );
      expect(adapter.requests[1].data, {
        'email': 'new.patient@example.com',
        'password': 'NeverPersistThisPassword123',
      });
      expect(
        adapter.requests[1].headers['Authorization'],
        'Bearer new-access-token',
      );
      expect(repository.pendingRegistration?.email, 'new.patient@example.com');
      expect(storage.pendingRegistration, {
        'userId': 'user-1',
        'step': 'patientDetails',
        'email': 'new.patient@example.com',
      });
      expect(
        jsonEncode(storage.pendingRegistration),
        isNot(contains('NeverPersistThisPassword123')),
      );

      await repository.savePatientProfile(
        firstName: 'Priya',
        lastName: 'Sharma',
        dateOfBirth: '1994-06-15',
        gender: 'Female',
        emergencyContact: '+919123456789',
        preferredLanguage: 'en',
      );
      expect(repository.pendingRegistration, isNull);
      expect(storage.pendingRegistration, isNull);
    });

    test('sends authenticated email change OTP requests', () async {
      await repository.sendEmailOtp(
        email: 'new@example.com',
        purpose: EmailOtpPurpose.emailChange,
      );
      final result = await repository.verifyEmailOtp(
        challengeId: 'challenge-1',
        email: 'new@example.com',
        purpose: EmailOtpPurpose.emailChange,
        otp: '123456',
      );

      expect(result, isA<EmailChangeOtpVerificationResponse>());
      expect(storage.accessToken, 'stored-access-token');
      expect(storage.refreshToken, 'stored-refresh-token');
      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer stored-access-token');
      }
    });

    test('sends authenticated initial-email activation requests', () async {
      await repository.sendEmailActivationOtp(
        email: ' New.Patient@Example.COM ',
      );
      await repository.verifyEmailActivationOtp(
        challengeId: 'challenge-activation',
        email: 'NEW.PATIENT@example.com',
        otp: '123456',
      );

      expect(adapter.requests.map((request) => request.path), [
        '/auth/email/activation/otp/send',
        '/auth/email/activation/otp/verify',
      ]);
      expect(
        adapter.requests.every(
          (request) =>
              request.headers['Authorization'] == 'Bearer stored-access-token',
        ),
        isTrue,
      );
      expect(adapter.requests[0].data, {'email': 'new.patient@example.com'});
      expect(adapter.requests[1].data, {
        'challengeId': 'challenge-activation',
        'email': 'new.patient@example.com',
        'otp': '123456',
      });
    });

    test(
      'logs in and persists tokens and session through shared storage',
      () async {
        final session = await repository.loginWithEmailPassword(
          email: ' Patient@Example.COM ',
          password: 'secret password',
          deviceInfo: 'Test device',
        );

        expect(session.user.id, 'user-1');
        expect(session.user.email, 'patient@example.com');
        expect(storage.accessToken, 'new-access-token');
        expect(storage.refreshToken, 'new-refresh-token');
        expect(storage.userSession?['userId'], 'user-1');
        expect(repository.currentSession, same(session));
        expect(repository.isAuthenticated, isTrue);
        expect(
          adapter.requests.single.headers.containsKey('Authorization'),
          isFalse,
        );
        expect(adapter.requests.single.data, {
          'email': 'patient@example.com',
          'password': 'secret password',
          'deviceInfo': 'Test device',
        });
      },
    );

    test(
      'clears a stale in-memory session when storage has no tokens',
      () async {
        apiClient.dio.httpClientAdapter = _RecordingAdapter(
          (_) => _sessionResponse(),
        );
        await repository.loginWithEmailPassword(
          email: 'patient@example.com',
          password: 'secure-password',
        );
        await storage.clearAll();

        expect(await repository.restoreSession(), isFalse);
        expect(repository.currentSession, isNull);
        expect(repository.isAuthenticated, isFalse);
      },
    );

    test(
      'posts authenticated password setup and unauthenticated reset completion',
      () async {
        await repository.setupPassword(password: 'new secure password');
        await repository.completePasswordReset(
          resetGrant: 'reset-grant',
          newPassword: 'another secure password',
        );

        expect(adapter.requests[0].path, '/auth/email/password/setup');
        expect(
          adapter.requests[0].headers['Authorization'],
          'Bearer stored-access-token',
        );
        expect(adapter.requests[0].data, {'password': 'new secure password'});
        expect(adapter.requests[1].path, '/auth/email/password/reset');
        expect(
          adapter.requests[1].headers.containsKey('Authorization'),
          isFalse,
        );
        expect(adapter.requests[1].data, {
          'resetGrant': 'reset-grant',
          'newPassword': 'another secure password',
        });
        expect(storage.accessToken, isNull);
        expect(storage.refreshToken, isNull);
        expect(storage.userSession, isNull);
        expect(repository.currentSession, isNull);
        expect(repository.isAuthenticated, isFalse);
      },
    );

    test(
      'logout revokes through the shared client then clears stored tokens',
      () async {
        await repository.logout();

        expect(adapter.requests.single.path, '/auth/logout');
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer stored-access-token',
        );
        expect(adapter.requests.single.data, {
          'refreshToken': 'stored-refresh-token',
        });
        expect(storage.accessToken, isNull);
        expect(storage.refreshToken, isNull);
        expect(storage.userSession, isNull);
        expect(repository.currentSession, isNull);
        expect(repository.isAuthenticated, isFalse);
      },
    );

    test('maps backend error envelopes to ApiError', () async {
      apiClient.dio.httpClientAdapter = _RecordingAdapter(
        (_) => {
          'statusCode': 401,
          'body': {
            'success': false,
            'errorCode': 'INVALID_EMAIL_OTP',
            'message': 'Verification code is invalid or has expired.',
            'details': {'remainingAttempts': 4},
          },
        },
      );

      try {
        await repository.sendEmailOtp(
          email: 'patient@example.com',
          purpose: EmailOtpPurpose.passwordReset,
        );
        fail('Expected an API error.');
      } on ApiError catch (error) {
        expect(error.statusCode, 401);
        expect(error.errorCode, 'INVALID_EMAIL_OTP');
        expect(error.remainingAttempts, 4);
      }
    });
  });

  group('Auth session restoration and refresh', () {
    test(
      'restores concurrent sessions with the single rotated refresh-token pair',
      () async {
        var refreshRequests = 0;
        var userRequests = 0;
        final server = await _startMockAuthServer((request) async {
          if (request.uri.path.endsWith('/auth/token/refresh')) {
            refreshRequests++;
            final body = jsonDecode(
              await utf8.decoder.bind(request).join(),
            ) as Map<String, dynamic>;
            expect(body['refreshToken'], 'expired-refresh-token');
            await _respond(request, 200, {
              'success': true,
              'data': {
                'accessToken': 'rotated-access-token',
                'refreshToken': 'rotated-refresh-token',
                'expiresIn': 900,
              },
            });
            return;
          }
          if (request.uri.path.endsWith('/auth/me')) {
            userRequests++;
            if (request.headers.value(HttpHeaders.authorizationHeader) !=
                'Bearer rotated-access-token') {
              await _respond(request, 401, {
                'success': false,
                'errorCode': 'TOKEN_EXPIRED',
                'message': 'Access token has expired.',
              });
              return;
            }
            await _respond(request, 200, {
              'success': true,
              'data': {
                'user': {
                  'id': 'user-1',
                  'phone': '+919876543210',
                  'role': 'PATIENT',
                  'status': 'ACTIVE',
                },
                'profile': null,
                'hasCompletedProfile': false,
              },
            });
            return;
          }
          await _respond(request, 404, {
            'success': false,
            'errorCode': 'NOT_FOUND',
            'message': 'Unexpected request.',
          });
        });
        final storage = _MemoryAuthStorage()
          ..accessToken = 'expired-access-token'
          ..refreshToken = 'expired-refresh-token';
        final apiClient = ApiClient(
          baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
          storage: storage,
        );
        final repository = AuthRepository(
          apiClient: apiClient,
          storage: storage,
        );
        addTearDown(() async {
          repository.sessionNotifier.dispose();
          repository.isAuthenticatedNotifier.dispose();
          repository.isSuspendedNotifier.dispose();
          apiClient.dio.close(force: true);
          await server.close(force: true);
        });

        final results = await Future.wait([
          repository.restoreSession(),
          repository.restoreSession(),
        ]);

        expect(results, [true, true]);
        expect(refreshRequests, 1);
        expect(userRequests, 4);
        expect(storage.accessToken, 'rotated-access-token');
        expect(storage.refreshToken, 'rotated-refresh-token');
        expect(
          repository.currentSession?.tokens.accessToken,
          'rotated-access-token',
        );
        expect(
          repository.currentSession?.tokens.refreshToken,
          'rotated-refresh-token',
        );
        expect(repository.isAuthenticated, isTrue);
      },
    );

    test('clears local session when refresh token is rejected', () async {
      var refreshRequests = 0;
      final server = await _startMockAuthServer((request) async {
        if (request.uri.path.endsWith('/auth/token/refresh')) {
          refreshRequests++;
          await _respond(request, 401, {
            'success': false,
            'errorCode': 'INVALID_REFRESH_TOKEN',
            'message': 'Invalid refresh token.',
          });
          return;
        }
        await _respond(request, 401, {
          'success': false,
          'errorCode': 'TOKEN_EXPIRED',
          'message': 'Access token has expired.',
        });
      });
      final storage = _MemoryAuthStorage()
        ..accessToken = 'expired-access-token'
        ..refreshToken = 'invalid-refresh-token';
      final apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
        storage: storage,
      );
      final repository = AuthRepository(apiClient: apiClient, storage: storage);
      addTearDown(() async {
        repository.sessionNotifier.dispose();
        repository.isAuthenticatedNotifier.dispose();
        repository.isSuspendedNotifier.dispose();
        apiClient.dio.close(force: true);
        await server.close(force: true);
      });

      expect(await repository.restoreSession(), isFalse);
      expect(refreshRequests, 1);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
      expect(repository.currentSession, isNull);
      expect(repository.isAuthenticated, isFalse);
    });
  });
}
