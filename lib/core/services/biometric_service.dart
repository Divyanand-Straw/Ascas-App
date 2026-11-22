import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService extends ChangeNotifier {
  BiometricService._();

  static final instance = BiometricService._();
  static const backgroundTimeout = Duration(seconds: 1);

  final LocalAuthentication _authentication = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _accountId;
  DateTime? _backgroundedAt;
  bool _enabled = false;
  bool _appLockEnabled = false;
  bool _locked = false;
  bool _authenticating = false;
  AppLockState _state = AppLockState.unlocked;

  bool get enabled => _enabled;
  bool get appLockEnabled => _appLockEnabled;
  bool get isLocked => _locked;
  bool get isAuthenticating => _authenticating;
  AppLockState get state => _state;

  Future<void> startSession(String accountId) async {
    if (accountId.isEmpty) return;
    _accountId = accountId;
    _backgroundedAt = null;
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_key(accountId)) ?? false;
    _appLockEnabled =
        preferences.getBool(_appLockKey(accountId)) ?? await hasPin(accountId);
    _locked = false;
    _state = AppLockState.unlocked;
    notifyListeners();
  }

  Future<bool> enable() async {
    if (_accountId == null) return false;
    final availability = await _availability();
    if (!availability.available || !availability.enrolled) return false;
    final authenticated = await _authenticate(
      'Authenticate to enable Thaai Seyali biometric app lock.',
    );
    if (!authenticated) return false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(_accountId!), true);
    await preferences.setBool(_appLockKey(_accountId!), true);
    _enabled = true;
    _state = AppLockState.unlocked;
    notifyListeners();
    return true;
  }

  Future<bool> disable() async {
    if (_accountId == null || !_enabled) return true;
    final authenticated = await _authenticate(
      'Authenticate to disable Thaai Seyali biometric app lock.',
    );
    if (!authenticated) return false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(_accountId!), false);
    _enabled = false;
    _state = AppLockState.unlocked;
    notifyListeners();
    return true;
  }

  Future<bool> setAppLockEnabled(bool value, {String? pin}) async {
    final accountId = _accountId;
    if (accountId == null || !await hasPin(accountId)) return false;
    if (!value) {
      final authenticated = pin == null
          ? await authenticateForSensitiveAction(
              'Authenticate to disable Thaai Seyali app lock.',
            )
          : await verifyPin(pin);
      if (!authenticated) return false;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_appLockKey(accountId), value);
    _appLockEnabled = value;
    if (!value) {
      _locked = false;
      _state = AppLockState.unlocked;
    }
    notifyListeners();
    return true;
  }

  Future<void> setPin({required String accountId, required String pin}) async {
    if (!_validPin(pin)) {
      throw StateError('Enter a valid 4-digit PIN.');
    }

    final salt = _randomSalt();
    await _secureStorage.write(key: _pinSaltKey(accountId), value: salt);
    await _secureStorage.write(
      key: _pinHashKey(accountId),
      value: _hashPin(pin, salt),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_appLockKey(accountId), true);
    if (_accountId == accountId) {
      _appLockEnabled = true;
      notifyListeners();
    }
  }

  Future<void> setBiometricPreference({
    required String accountId,
    required bool enabled,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(accountId), enabled);
    if (enabled) await preferences.setBool(_appLockKey(accountId), true);
    if (_accountId == accountId) {
      _enabled = enabled;
      if (enabled) _appLockEnabled = true;
      notifyListeners();
    }
  }

  Future<bool> hasPin(String accountId) async =>
      await _secureStorage.read(key: _pinHashKey(accountId)) != null;

  Future<bool> verifyPin(String pin, {String? accountId}) async {
    final id = accountId ?? _accountId;
    if (id == null || !_validPin(pin)) return false;
    final salt = await _secureStorage.read(key: _pinSaltKey(id));
    final storedHash = await _secureStorage.read(key: _pinHashKey(id));
    if (salt == null || storedHash == null) return false;
    return _constantTimeEquals(storedHash, _hashPin(pin, salt));
  }

  Future<bool> unlockWithPin(String pin) async {
    if (!_locked || _authenticating) return !_locked;
    final authenticated = await verifyPin(pin);
    if (authenticated) {
      _locked = false;
      _state = AppLockState.unlocked;
      notifyListeners();
    } else {
      _state = AppLockState.authenticationFailed;
      notifyListeners();
    }
    return authenticated;
  }

  Future<bool> authenticateForSensitiveAction(String reason) async {
    if (_enabled) {
      final authenticated = await _authenticate(reason);
      if (authenticated) return true;
    }
    return false;
  }

  Future<void> changePin({
    required String accountId,
    required String currentPin,
    required String newPin,
  }) async {
    if (!await verifyPin(currentPin, accountId: accountId)) {
      throw StateError('The current PIN is incorrect.');
    }
    await setPin(accountId: accountId, pin: newPin);
  }

  Future<BiometricAvailability> availability() => _availability();

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (!_appLockEnabled || _accountId == null) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // Inactive is also emitted when a system surface, such as the
      // notification shade, temporarily takes focus. Hidden/paused indicate
      // that the application actually left the foreground.
      if (_authenticating) return;
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed ||
        _backgroundedAt == null ||
        _authenticating) {
      return;
    }
    final elapsed = DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    if (elapsed < backgroundTimeout) return;
    if (_locked) return;
    _locked = true;
    _state = AppLockState.locked;
    notifyListeners();
    await unlock();
  }

  Future<bool> unlock() async {
    if (!_locked || _authenticating) return !_locked;
    if (!_enabled) return false;
    final authenticated = await _authenticate(
      'Authenticate to unlock Thaai Seyali.',
    );
    if (authenticated) {
      _locked = false;
      _state = AppLockState.unlocked;
      notifyListeners();
    }
    return authenticated;
  }

  void endSession() {
    _accountId = null;
    _backgroundedAt = null;
    _enabled = false;
    _appLockEnabled = false;
    _locked = false;
    _authenticating = false;
    _state = AppLockState.unlocked;
    notifyListeners();
  }

  Future<BiometricAvailability> _availability() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final canCheck = await _authentication.canCheckBiometrics;
      final types = canCheck
          ? await _authentication.getAvailableBiometrics()
          : <BiometricType>[];
      return BiometricAvailability(
        available: supported && canCheck,
        enrolled: types.isNotEmpty,
      );
    } on LocalAuthException {
      return const BiometricAvailability(available: false, enrolled: false);
    }
  }

  Future<bool> _authenticate(String reason) async {
    if (_authenticating) return false;
    _authenticating = true;
    _state = AppLockState.authenticating;
    notifyListeners();
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      _state = authenticated
          ? AppLockState.authenticationSuccessful
          : AppLockState.authenticationFailed;
      return authenticated;
    } on LocalAuthException {
      _state = AppLockState.authenticationFailed;
      return false;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }

  String _key(String accountId) => 'biometric_app_lock_$accountId';
  String _appLockKey(String accountId) => 'app_lock_enabled_$accountId';
  String _pinHashKey(String accountId) => 'security_pin_hash_$accountId';
  String _pinSaltKey(String accountId) => 'security_pin_salt_$accountId';

  bool _validPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  bool _constantTimeEquals(String first, String second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first.codeUnitAt(index) ^ second.codeUnitAt(index);
    }
    return difference == 0;
  }
}

enum AppLockState {
  unlocked,
  locked,
  authenticating,
  authenticationSuccessful,
  authenticationFailed,
}

class BiometricAvailability {
  final bool available;
  final bool enrolled;

  const BiometricAvailability({
    required this.available,
    required this.enrolled,
  });
}
