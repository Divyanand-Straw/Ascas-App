import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
    const Locale('en'),
  );

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final language = preferences.getString('app_language');
    if (language == 'ta') {
      locale.value = const Locale('ta');
    }
  }

  static Future<void> setLanguage(String languageCode) async {
    final localeValue = Locale(languageCode);
    locale.value = localeValue;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app_language', languageCode);
  }
}
