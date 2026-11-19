import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyAccessToken = 'ascas_auth_access_token';
  static const String _keyRefreshToken = 'ascas_auth_refresh_token';
  static const String _keyUserId = 'ascas_auth_user_id';
  static const String _keyPhone = 'ascas_auth_user_phone';
  static const String _keyRole = 'ascas_auth_user_role';
  static const String _keyHasCompletedProfile = 'ascas_auth_has_completed_profile';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

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

  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyPhone);
    await _storage.delete(key: _keyRole);
    await _storage.delete(key: _keyHasCompletedProfile);
  }
}
