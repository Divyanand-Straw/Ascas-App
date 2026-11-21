import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/auth_models.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient, AuthTokenStorage? storage})
    : _api = apiClient ?? ApiClient.instance,
      _storage = storage ?? SecureStorageService.instance {
    // Listen for forced logouts from interceptor (e.g. refresh failure or suspension)
    _api.authInterceptor.onSessionExpired = _handleSessionExpired;
    _api.authInterceptor.onAccountSuspended = _handleAccountSuspended;
  }

  static final AuthRepository instance = AuthRepository();

  final ApiClient _api;
  final AuthTokenStorage _storage;

  final ValueNotifier<AuthSession?> sessionNotifier =
      ValueNotifier<AuthSession?>(null);
  final ValueNotifier<bool> isAuthenticatedNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> isSuspendedNotifier = ValueNotifier<bool>(false);

  PendingNewPatientRegistration? _pendingRegistration;

  AuthSession? get currentSession => sessionNotifier.value;
  bool get isAuthenticated => isAuthenticatedNotifier.value;
  PendingNewPatientRegistration? get pendingRegistration =>
      _pendingRegistration;

  void _handleSessionExpired() {
    sessionNotifier.value = null;
    isAuthenticatedNotifier.value = false;
  }

  void _handleAccountSuspended() {
    sessionNotifier.value = null;
    isAuthenticatedNotifier.value = false;
    isSuspendedNotifier.value = true;
  }

  /// Normalizes phone number to E.164 format
  String normalizePhone(String input) {
    final clean = input.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
      return '+91$clean';
    }
    if (RegExp(r'^\+?[1-9]\d{9,14}$').hasMatch(clean)) {
      return clean.startsWith('+') ? clean : '+$clean';
    }
    return clean;
  }

  /// 1. Request OTP challenge
  Future<SendOtpResponse> sendOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    final normalized = normalizePhone(phone);
    final request = SendOtpRequest(phone: normalized, purpose: purpose);

    final response = await _api.post('/auth/otp/send', data: request.toJson());

    try {
      final data = _mobileOtpResponseData(
        response.data,
        operation: 'requesting a verification code',
      );
      return SendOtpResponse.fromJson(data);
    } on FormatException catch (_) {
      throw _invalidOtpResponse('requesting a verification code');
    } on TypeError catch (_) {
      throw _invalidOtpResponse('requesting a verification code');
    }
  }

  /// 2. Verify OTP challenge
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String phone,
    required OtpPurpose purpose,
    required String otp,
    String? deviceInfo,
  }) async {
    final normalized = normalizePhone(phone);
    final request = VerifyOtpRequest(
      challengeId: challengeId,
      phone: normalized,
      purpose: purpose,
      otp: otp,
      deviceInfo: deviceInfo,
    );

    final response = await _api.post(
      '/auth/otp/verify',
      data: request.toJson(),
    );

    late final AuthSession session;
    try {
      final data = _mobileOtpResponseData(
        response.data,
        operation: 'verifying the code',
      );
      session = AuthSession.fromJson(data);
    } on FormatException catch (_) {
      throw _invalidOtpResponse('verifying the code');
    } on TypeError catch (_) {
      throw _invalidOtpResponse('verifying the code');
    }

    await _storeAuthenticatedSession(session);
    if (purpose == OtpPurpose.registration && session.isNewUser) {
      await _savePendingRegistration(
        session.user.id,
        PendingRegistrationStep.credentials,
        '',
      );
    } else {
      await _restorePendingRegistration(
        session.user.id,
        hasCompletedProfile: session.hasCompletedProfile,
      );
    }

    return session;
  }

  Map<String, dynamic> _mobileOtpResponseData(
    dynamic responseData, {
    required String operation,
  }) {
    if (responseData is Map<String, dynamic> &&
        responseData['data'] is Map<String, dynamic>) {
      return responseData['data'] as Map<String, dynamic>;
    }
    throw _invalidOtpResponse(operation);
  }

  ApiError _invalidOtpResponse(String operation) => ApiError(
    statusCode: 502,
    errorCode: 'INVALID_SERVER_RESPONSE',
    message:
        'The server returned an invalid response while $operation. Please try again.',
  );

  Future<PatientProfileData> savePatientProfile({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String emergencyContact,
    String? gender,
    required String preferredLanguage,
  }) async {
    final request = SavePatientProfileRequest(
      firstName: firstName,
      lastName: lastName,
      dob: dateOfBirth,
      emergencyContact: emergencyContact,
      gender: gender,
      preferredLanguage: preferredLanguage,
    );
    final response = await _api.post('/auth/profile', data: request.toJson());
    final data = response.data['data'] as Map<String, dynamic>;
    final profile = PatientProfileData.fromJson(data);
    if (profile.id.isEmpty ||
        profile.userId == null ||
        profile.userId!.isEmpty) {
      throw const FormatException(
        'The server returned an incomplete patient profile.',
      );
    }
    final current = sessionNotifier.value;
    if (current != null && profile.userId != current.user.id) {
      throw const FormatException(
        'The server returned a profile for a different account.',
      );
    }
    if (current != null) {
      sessionNotifier.value = AuthSession(
        user: current.user,
        profile: profile,
        tokens: current.tokens,
        isNewUser: current.isNewUser,
        hasCompletedProfile: true,
      );
      await _storage.saveUserSession(
        userId: current.user.id,
        phone: current.user.phone,
        role: current.user.role,
        hasCompletedProfile: true,
      );
      if (_pendingRegistration?.userId == current.user.id) {
        await _storage.clearPendingRegistration();
        _pendingRegistration = null;
      }
    }
    return profile;
  }

  Future<void> updatePatientProfile({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    String? gender,
    required String preferredLanguage,
  }) async {
    final response = await _api.put(
      '/auth/profile',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'dob': dateOfBirth,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        'preferredLanguage': preferredLanguage,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final profile = PatientProfileData.fromJson(data);
    final current = sessionNotifier.value;
    if (current != null) {
      sessionNotifier.value = AuthSession(
        user: current.user,
        profile: profile,
        tokens: current.tokens,
        isNewUser: current.isNewUser,
        hasCompletedProfile: true,
      );
    }
  }

  Future<void> setupRegistrationCredentials({
    required String email,
    required String password,
  }) async {
    final session = sessionNotifier.value;
    if (session == null) {
      throw StateError('The verified registration session is unavailable.');
    }
    final pending = _pendingRegistration;
    if (pending?.userId != session.user.id ||
        pending?.step != PendingRegistrationStep.credentials) {
      throw StateError('The verified registration step is unavailable.');
    }
    final normalizedEmail = normalizeEmail(email);
    await _api.post(
      '/auth/email/password/registration-setup',
      data: SetupRegistrationCredentialsRequest(
        email: normalizedEmail,
        password: password,
      ).toJson(),
    );
    sessionNotifier.value = AuthSession(
      user: session.user.copyWith(email: normalizedEmail),
      profile: session.profile,
      tokens: session.tokens,
      isNewUser: session.isNewUser,
      hasCompletedProfile: session.hasCompletedProfile,
    );
    await _savePendingRegistration(
      session.user.id,
      PendingRegistrationStep.patientDetails,
      normalizedEmail,
    );
  }

  Future<SendEmailOtpResponse> sendEmailOtp({
    required String email,
    required EmailOtpPurpose purpose,
  }) async {
    final request = SendEmailOtpRequest(email: email, purpose: purpose);
    final response = await _api.post(
      '/auth/email/otp/send',
      data: request.toJson(),
    );
    return SendEmailOtpResponse.fromJson(_requireDataMap(response.data));
  }

  Future<SendEmailOtpResponse> sendPasswordResetOtp({
    required String phone,
    required String email,
  }) async {
    final response = await _api.post(
      '/auth/email/password/reset/otp/send',
      data: PasswordResetOtpRequest(phone: phone, email: email).toJson(),
    );
    return SendEmailOtpResponse.fromJson(_requireDataMap(response.data));
  }

  Future<SendEmailOtpResponse> sendDeveloperEmailTestOtp({
    required String email,
  }) async {
    final request = DeveloperEmailTestOtpRequest(email: email);
    final response = await _api.post(
      '/auth/email/developer-test/otp/send',
      data: request.toJson(),
    );
    return SendEmailOtpResponse.fromJson(_requireDataMap(response.data));
  }

  Future<DeveloperEmailTestOtpVerificationResponse>
  verifyDeveloperEmailTestOtp({
    required String challengeId,
    required String email,
    required String otp,
  }) async {
    final request = VerifyDeveloperEmailTestOtpRequest(
      challengeId: challengeId,
      email: email,
      otp: otp,
    );
    final response = await _api.post(
      '/auth/email/developer-test/otp/verify',
      data: request.toJson(),
    );
    return DeveloperEmailTestOtpVerificationResponse.fromJson(
      _requireDataMap(response.data),
    );
  }

  Future<SendEmailOtpResponse> sendEmailActivationOtp({
    required String email,
  }) async {
    final request = SendEmailActivationOtpRequest(email: email);
    final response = await _api.post(
      '/auth/email/activation/otp/send',
      data: request.toJson(),
    );
    return SendEmailOtpResponse.fromJson(_requireDataMap(response.data));
  }

  Future<EmailActivationOtpVerificationResponse> verifyEmailActivationOtp({
    required String challengeId,
    required String email,
    required String otp,
  }) async {
    final request = VerifyEmailActivationOtpRequest(
      challengeId: challengeId,
      email: email,
      otp: otp,
    );
    final response = await _api.post(
      '/auth/email/activation/otp/verify',
      data: request.toJson(),
    );
    return EmailActivationOtpVerificationResponse.fromJson(
      _requireDataMap(response.data),
    );
  }

  Future<VerifyEmailOtpResponse> verifyEmailOtp({
    required String challengeId,
    required String email,
    required EmailOtpPurpose purpose,
    required String otp,
  }) async {
    final request = VerifyEmailOtpRequest(
      challengeId: challengeId,
      email: email,
      purpose: purpose,
      otp: otp,
    );
    final response = await _api.post(
      '/auth/email/otp/verify',
      data: request.toJson(),
    );
    return VerifyEmailOtpResponse.fromJson(_requireDataMap(response.data));
  }

  Future<AuthSession> loginWithEmailPassword({
    required String email,
    required String password,
    String? deviceInfo,
  }) async {
    final request = EmailPasswordLoginRequest(
      email: email,
      password: password,
      deviceInfo: deviceInfo,
    );
    final response = await _api.post(
      '/auth/email/password/login',
      data: request.toJson(),
    );
    final session = AuthSession.fromJson(_requireDataMap(response.data));
    await _storeAuthenticatedSession(session);
    await _restorePendingRegistration(
      session.user.id,
      hasCompletedProfile: session.hasCompletedProfile,
    );
    return session;
  }

  Future<void> setupPassword({required String password}) async {
    await _api.post(
      '/auth/email/password/setup',
      data: SetupPasswordRequest(password: password).toJson(),
    );
  }

  Future<void> completePasswordReset({
    required String resetGrant,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/email/password/reset',
      data: CompletePasswordResetRequest(
        resetGrant: resetGrant,
        newPassword: newPassword,
      ).toJson(),
    );
    await _storage.clearAll();
    sessionNotifier.value = null;
    isAuthenticatedNotifier.value = false;
    isSuspendedNotifier.value = false;
  }

  /// 3. Refresh Access Token
  Future<AuthTokens> refreshTokens() async {
    final currentRefreshToken = await _storage.getRefreshToken();
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      throw ApiError(
        statusCode: 401,
        errorCode: 'UNAUTHORIZED',
        message: 'No active session found.',
      );
    }

    final response = await _api.post(
      '/auth/token/refresh',
      data: {'refreshToken': currentRefreshToken},
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final tokens = AuthTokens.fromJson(data);

    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return tokens;
  }

  /// 4. Logout Session
  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _api.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {
      // Best-effort logout; continue to wipe local tokens even if server is unreachable
    } finally {
      await _storage.clearAll();
      sessionNotifier.value = null;
      isAuthenticatedNotifier.value = false;
    }
  }

  /// 5. Inspect Authenticated User Session
  Future<CurrentUserResponse> getCurrentUser() async {
    final response = await _api.get('/auth/me');
    final data = response.data['data'] as Map<String, dynamic>;
    return CurrentUserResponse.fromJson(data);
  }

  Future<AuthSession> refreshCurrentUser() async {
    final current = sessionNotifier.value;
    if (current == null) {
      throw StateError('The authenticated session is unavailable.');
    }
    final response = await getCurrentUser();
    if (response.user.id != current.user.id) {
      throw const FormatException(
        'The server returned a different authenticated account.',
      );
    }
    final refreshed = AuthSession(
      user: response.user,
      profile: response.profile,
      tokens: current.tokens,
      isNewUser: current.isNewUser,
      hasCompletedProfile: response.hasCompletedProfile,
    );
    sessionNotifier.value = refreshed;
    return refreshed;
  }

  /// 6. Restore authenticated session on app launch
  Future<bool> restoreSession() async {
    try {
      final token = await _storage.getAccessToken();
      final refreshToken = await _storage.getRefreshToken();

      if (token == null && refreshToken == null) {
        sessionNotifier.value = null;
        isAuthenticatedNotifier.value = false;
        return false;
      }

      final userResponse = await getCurrentUser();
      final restoredAccessToken = await _storage.getAccessToken();
      final restoredRefreshToken = await _storage.getRefreshToken();
      if (restoredAccessToken == null || restoredAccessToken.isEmpty) {
        throw ApiError(
          statusCode: 401,
          errorCode: 'UNAUTHORIZED',
          message: 'No active session found.',
        );
      }

      sessionNotifier.value = AuthSession(
        user: userResponse.user,
        profile: userResponse.profile,
        tokens: AuthTokens(
          accessToken: restoredAccessToken,
          refreshToken: restoredRefreshToken ?? '',
          expiresIn: 900,
        ),
        isNewUser: false,
        hasCompletedProfile: userResponse.hasCompletedProfile,
      );

      isAuthenticatedNotifier.value = true;
      if (userResponse.hasCompletedProfile) {
        final pending = await _storage.getPendingRegistration();
        if (pending?['userId'] == userResponse.user.id) {
          await _storage.clearPendingRegistration();
        }
        _pendingRegistration = null;
      } else {
        await _restorePendingRegistration(userResponse.user.id);
      }
      return true;
    } catch (e) {
      // Session could not be restored
      await _storage.clearAll();
      sessionNotifier.value = null;
      isAuthenticatedNotifier.value = false;
      return false;
    }
  }

  Future<void> _storeAuthenticatedSession(AuthSession session) async {
    await _storage.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );
    await _storage.saveUserSession(
      userId: session.user.id,
      phone: session.user.phone,
      role: session.user.role,
      hasCompletedProfile: session.hasCompletedProfile,
    );
    sessionNotifier.value = session;
    isAuthenticatedNotifier.value = true;
    isSuspendedNotifier.value = false;
  }

  Future<void> _savePendingRegistration(
    String userId,
    PendingRegistrationStep step,
    String email,
  ) async {
    await _storage.savePendingRegistration(
      userId: userId,
      step: step.storageValue,
      email: email,
    );
    _pendingRegistration = PendingNewPatientRegistration(
      userId: userId,
      step: step,
      email: email,
    );
  }

  Future<void> _restorePendingRegistration(
    String userId, {
    bool hasCompletedProfile = false,
  }) async {
    final stored = await _storage.getPendingRegistration();
    if (stored == null || stored['userId'] != userId) {
      _pendingRegistration = null;
      return;
    }
    if (hasCompletedProfile) {
      await _storage.clearPendingRegistration();
      _pendingRegistration = null;
      return;
    }
    final step = PendingRegistrationStep.fromStorageValue(stored['step'] ?? '');
    if (step == null) {
      await _storage.clearPendingRegistration();
      _pendingRegistration = null;
      return;
    }
    _pendingRegistration = PendingNewPatientRegistration(
      userId: userId,
      step: step,
      email: stored['email'] ?? '',
    );
  }

  Map<String, dynamic> _requireDataMap(dynamic responseData) {
    if (responseData is Map && responseData['data'] is Map) {
      return Map<String, dynamic>.from(responseData['data'] as Map);
    }
    throw ApiError(
      statusCode: 500,
      errorCode: 'INVALID_RESPONSE',
      message: 'The server returned an invalid authentication response.',
    );
  }
}
