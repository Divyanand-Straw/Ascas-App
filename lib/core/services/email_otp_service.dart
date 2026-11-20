import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailOtpService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'EMAIL_OTP_API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  static Future<String> requestOtp(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/auth/request-email-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['message'] ?? 'OTP sent successfully.';
      }
      throw Exception(data['detail'] ?? 'Unable to send OTP.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unable to connect to the email server.');
    }
  }

  static Future<String> verifyOtp(String email, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/auth/verify-email-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['verified'] == true) {
        return data['message'] ?? 'Email verified successfully.';
      }
      throw Exception(data['detail'] ?? 'OTP verification failed.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unable to connect to the email server.');
    }
  }
}
