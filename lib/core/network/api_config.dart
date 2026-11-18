import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  ApiConfig._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL for the ASCAS Node.js Express backend API (/api/v1)
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api/v1';
    }

    try {
      if (Platform.isAndroid) {
        // Android Emulator loopback to host
        return 'http://10.0.2.2:5000/api/v1';
      } else if (Platform.isIOS || Platform.isMacOS) {
        return 'http://localhost:5000/api/v1';
      }
    } catch (_) {
      // Fallback
    }

    return 'http://localhost:5000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
