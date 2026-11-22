import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import 'api_config.dart';

typedef AuthSessionExpiredCallback = void Function();
typedef AccountSuspendedCallback = void Function();

class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  final AuthTokenStorage storage;
  AuthSessionExpiredCallback? onSessionExpired;
  AccountSuspendedCallback? onAccountSuspended;

  AuthInterceptor({
    required this.dio,
    AuthTokenStorage? storage,
    this.onSessionExpired,
    this.onAccountSuspended,
  }) : storage = storage ?? SecureStorageService.instance;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip injecting auth token for public authentication routes
    final requestPurpose = options.data is Map
        ? (options.data as Map)['purpose']
        : null;
    final isPublicAuthPath =
        options.path.contains('/auth/otp/send') ||
        options.path.contains('/auth/otp/verify') ||
        options.path.contains('/auth/token/refresh') ||
        options.path.contains('/auth/email/password/login') ||
        options.path.contains('/auth/email/password/reset') ||
        options.path.contains('/auth/email/developer-test/otp/send') ||
        options.path.contains('/auth/email/developer-test/otp/verify') ||
        (requestPurpose == 'PASSWORD_RESET' &&
            options.path.contains('/auth/email/otp/'));

    if (!isPublicAuthPath) {
      final token = await storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final statusCode = response?.statusCode;
    final data = response?.data is Map<String, dynamic>
        ? response?.data as Map<String, dynamic>
        : null;
    final errorCode = data?['errorCode'] as String?;

    // 1. Account suspended
    if (statusCode == 403 && errorCode == 'ACCOUNT_SUSPENDED') {
      await storage.clearAll();
      onAccountSuspended?.call();
      return handler.reject(err);
    }

    // 2. Token expired: attempt automatic silent refresh
    final isRefreshRoute = err.requestOptions.path.contains(
      '/auth/token/refresh',
    );
    final isLogoutRoute = err.requestOptions.path.contains('/auth/logout');
    final isVerifyRoute = err.requestOptions.path.contains('/auth/otp/verify');

    if (statusCode == 401 &&
        !isRefreshRoute &&
        !isLogoutRoute &&
        !isVerifyRoute) {
      if (errorCode == 'TOKEN_EXPIRED' || errorCode == 'UNAUTHORIZED') {
        try {
          // Check if another concurrent request already refreshed the access token
          final currentAccessToken = await storage.getAccessToken();
          final requestAuthHeader =
              err.requestOptions.headers['Authorization'] as String?;
          final requestToken =
              requestAuthHeader != null &&
                  requestAuthHeader.startsWith('Bearer ')
              ? requestAuthHeader.substring(7)
              : null;

          if (currentAccessToken != null &&
              currentAccessToken.isNotEmpty &&
              requestToken != null &&
              currentAccessToken != requestToken) {
            // Token was already refreshed by a preceding queued request; retry immediately with new token
            final originalRequest = err.requestOptions;
            originalRequest.headers['Authorization'] =
                'Bearer $currentAccessToken';
            final retryResponse = await dio.fetch(originalRequest);
            return handler.resolve(retryResponse);
          }

          final refreshToken = await storage.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            await storage.clearAll();
            onSessionExpired?.call();
            return handler.reject(err);
          }

          // Execute refresh via dedicated non-intercepted Dio instance
          final refreshDio = Dio(
            BaseOptions(
              baseUrl: dio.options.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              headers: {'Content-Type': 'application/json'},
            ),
          );

          final refreshResponse = await refreshDio.post(
            '/auth/token/refresh',
            data: {'refreshToken': refreshToken},
          );

          if (refreshResponse.statusCode == 200) {
            final payload =
                refreshResponse.data['data'] as Map<String, dynamic>;
            final newAccessToken = payload['accessToken'] as String;
            final newRefreshToken = payload['refreshToken'] as String;

            // Save rotated tokens
            await storage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );

            // Retry the original failed request with the new access token
            final originalRequest = err.requestOptions;
            originalRequest.headers['Authorization'] = 'Bearer $newAccessToken';

            final retryResponse = await dio.fetch(originalRequest);
            return handler.resolve(retryResponse);
          }
        } catch (_) {
          // Token refresh failed (expired or reuse detected)
          await storage.clearAll();
          onSessionExpired?.call();
          return handler.reject(err);
        }
      }
    }

    return handler.next(err);
  }
}
