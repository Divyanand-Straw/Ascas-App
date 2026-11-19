import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/auth_models.dart';

class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    SecureStorageService? storage,
  })  : _api = apiClient ?? ApiClient.instance,
        _storage = storage ?? SecureStorageService.instance {
    // Listen for forced logouts from interceptor (e.g. refresh failure or suspension)
    _api.authInterceptor.onSessionExpired = _handleSessionExpired;
    _api.authInterceptor.onAccountSuspended = _handleAccountSuspended;
  }

  static final AuthRepository instance = AuthRepository();

  final ApiClient _api;
  final SecureStorageService _storage;

  final ValueNotifier<AuthSession?> sessionNotifier = ValueNotifier<AuthSession?>(null);
  final ValueNotifier<bool> isAuthenticatedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSuspendedNotifier = ValueNotifier<bool>(false);

  AuthSession? get currentSession => sessionNotifier.value;
  bool get isAuthenticated => isAuthenticatedNotifier.value;

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

    final response = await _api.post(
      '/auth/otp/send',
      data: request.toJson(),
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return SendOtpResponse.fromJson(data);
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

    final data = response.data['data'] as Map<String, dynamic>;
    final session = AuthSession.fromJson(data);

    // Persist tokens securely
    await _storage.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );

    // Persist user session info
    await _storage.saveUserSession(
      userId: session.user.id,
      phone: session.user.phone,
      role: session.user.role,
      hasCompletedProfile: session.hasCompletedProfile,
    );

    sessionNotifier.value = session;
    isAuthenticatedNotifier.value = true;
    isSuspendedNotifier.value = false;

    return session;
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
        await _api.post(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
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

  /// 6. Restore authenticated session on app launch
  Future<bool> restoreSession() async {
    try {
      final token = await _storage.getAccessToken();
      final refreshToken = await _storage.getRefreshToken();

      if (token == null && refreshToken == null) {
        isAuthenticatedNotifier.value = false;
        return false;
      }

      final userResponse = await getCurrentUser();

      sessionNotifier.value = AuthSession(
        user: userResponse.user,
        profile: userResponse.profile,
        tokens: AuthTokens(
          accessToken: token ?? '',
          refreshToken: refreshToken ?? '',
          expiresIn: 900,
        ),
        isNewUser: false,
        hasCompletedProfile: userResponse.hasCompletedProfile,
      );

      isAuthenticatedNotifier.value = true;
      return true;
    } catch (e) {
      // Session could not be restored
      await _storage.clearAll();
      sessionNotifier.value = null;
      isAuthenticatedNotifier.value = false;
      return false;
    }
  }
}
