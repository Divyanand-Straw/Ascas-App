import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthTokenStorage {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<void> saveUserSession({
    required String userId,
    required String phone,
    required String role,
    required bool hasCompletedProfile,
  });

  Future<Map<String, dynamic>?> getUserSession();

  Future<void> savePendingRegistration({
    required String userId,
    required String step,
    required String email,
  });

  Future<Map<String, String>?> getPendingRegistration();

  Future<void> clearPendingRegistration();

  Future<void> clearAll();
}

class SecureStorageService implements AuthTokenStorage {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyAccessToken = 'ascas_auth_access_token';
  static const String _keyRefreshToken = 'ascas_auth_refresh_token';
  static const String _keyUserId = 'ascas_auth_user_id';
  static const String _keyPhone = 'ascas_auth_user_phone';
  static const String _keyRole = 'ascas_auth_user_role';
  static const String _keyHasCompletedProfile =
      'ascas_auth_has_completed_profile';
  static const String _keyPendingRegistrationUserId =
      'ascas_pending_registration_user_id';
  static const String _keyPendingRegistrationStep =
      'ascas_pending_registration_step';
  static const String _keyPendingRegistrationEmail =
      'ascas_pending_registration_email';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  @override
  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  @override
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  @override
  Future<void> saveUserSession({
    required String userId,
    required String phone,
    required String role,
    required bool hasCompletedProfile,
  }) async {
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyPhone, value: phone);
    await _storage.write(key: _keyRole, value: role);
    await _storage.write(
      key: _keyHasCompletedProfile,
      value: hasCompletedProfile ? 'true' : 'false',
    );
  }

  @override
  Future<Map<String, dynamic>?> getUserSession() async {
    final userId = await _storage.read(key: _keyUserId);
    if (userId == null) return null;

    final phone = await _storage.read(key: _keyPhone) ?? '';
    final role = await _storage.read(key: _keyRole) ?? 'PATIENT';
    final hasCompletedProfile =
        (await _storage.read(key: _keyHasCompletedProfile)) == 'true';

    return {
      'userId': userId,
      'phone': phone,
      'role': role,
      'hasCompletedProfile': hasCompletedProfile,
    };
  }

  @override
  Future<void> savePendingRegistration({
    required String userId,
    required String step,
    required String email,
  }) async {
    await _storage.write(key: _keyPendingRegistrationUserId, value: userId);
    await _storage.write(key: _keyPendingRegistrationStep, value: step);
    await _storage.write(key: _keyPendingRegistrationEmail, value: email);
  }

  @override
  Future<Map<String, String>?> getPendingRegistration() async {
    final userId = await _storage.read(key: _keyPendingRegistrationUserId);
    final step = await _storage.read(key: _keyPendingRegistrationStep);
    if (userId == null || step == null) return null;
    return {
      'userId': userId,
      'step': step,
      'email': await _storage.read(key: _keyPendingRegistrationEmail) ?? '',
    };
  }

  @override
  Future<void> clearPendingRegistration() async {
    await _storage.delete(key: _keyPendingRegistrationUserId);
    await _storage.delete(key: _keyPendingRegistrationStep);
    await _storage.delete(key: _keyPendingRegistrationEmail);
  }

  @override
  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyPhone);
    await _storage.delete(key: _keyRole);
    await _storage.delete(key: _keyHasCompletedProfile);
    // Keep this password-free marker so an interrupted New Patient flow can resume after logout.
  }
}
