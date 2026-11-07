import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

class LocaleService {
  static const _preferencesKey = 'patient_language_preferences';
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
    const Locale('en'),
  );
  static String? _activeAccountId;

  static Future<void> load() async {
    // The logged-out shell is always English. Account preferences are loaded
    // only after an authenticated account is established.
    locale.value = const Locale('en');
  }

  static Future<String> languageForAccount(String accountId) async {
    final preferences = await SharedPreferences.getInstance();
    final values = _readPreferences(preferences);
    return values[accountId] == 'ta' ? 'ta' : 'en';
  }

  static Future<void> setAccount(String accountId) async {
    _activeAccountId = accountId;
    await setLanguage(await languageForAccount(accountId));
  }

  static Future<void> setLanguage(
    String languageCode, {
    String? accountId,
  }) async {
    final normalized = languageCode == 'ta' ? 'ta' : 'en';
    locale.value = Locale(normalized);
    final effectiveAccountId = accountId ?? _activeAccountId;
    if (effectiveAccountId == null || effectiveAccountId.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    final values = _readPreferences(preferences);
    values[effectiveAccountId] = normalized;
    await preferences.setString(_preferencesKey, jsonEncode(values));
  }

  static Future<void> setAccountLanguage({
    required String accountId,
    required String languageCode,
  }) async {
    _activeAccountId = accountId;
    await setLanguage(languageCode, accountId: accountId);
  }

  static Future<void> resetForLogout() async {
    _activeAccountId = null;
    locale.value = const Locale('en');
  }

  // Kept for the registration UI. Pre-login language selection must not
  // change the logged-out shell or create a device-wide preference.
  static Future<void> rememberLanguage(String languageCode) async {}

  static Map<String, String> _readPreferences(SharedPreferences preferences) {
    final raw = preferences.getString(_preferencesKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value == 'ta' ? 'ta' : 'en'),
        );
      }
    } on FormatException {
      // An invalid prototype value is ignored and replaced on the next save.
    }
    return <String, String>{};
  }
}
