import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService extends ChangeNotifier {
  BiometricService._();

  static final instance = BiometricService._();
  static const backgroundTimeout = Duration(seconds: 1);

  final LocalAuthentication _authentication = LocalAuthentication();
  String? _accountId;
  DateTime? _backgroundedAt;
  bool _enabled = false;
  bool _locked = false;
  bool _authenticating = false;
  AppLockState _state = AppLockState.unlocked;

  bool get enabled => _enabled;
  bool get isLocked => _locked;
  bool get isAuthenticating => _authenticating;
  AppLockState get state => _state;

  Future<void> startSession(String accountId) async {
    if (accountId.isEmpty) return;
    _accountId = accountId;
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_key(accountId)) ?? false;
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

  Future<BiometricAvailability> availability() => _availability();

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (!_enabled || _accountId == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // local_auth may pause the app while its Android prompt is displayed.
      // That transition must not be treated as the app leaving the session.
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
    _locked = true;
    _state = AppLockState.locked;
    notifyListeners();
    await unlock();
  }

  Future<bool> unlock() async {
    if (!_locked || _authenticating) return !_locked;
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
