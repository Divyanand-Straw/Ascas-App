import 'package:dio/dio.dart';

import 'api_config.dart';
import 'auth_interceptor.dart';
import '../storage/secure_storage_service.dart';
import '../../features/auth/data/models/auth_models.dart';

class ApiClient {
  ApiClient({String? baseUrl, AuthTokenStorage? storage}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _authInterceptor = AuthInterceptor(dio: _dio, storage: storage);
    _dio.interceptors.add(_authInterceptor);
  }

  static final ApiClient instance = ApiClient();

  late final Dio _dio;
  late final AuthInterceptor _authInterceptor;

  Dio get dio => _dio;
  AuthInterceptor get authInterceptor => _authInterceptor;

  /// Updates or overrides the base URL dynamically
  void setBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  /// Maps a DioException or unexpected error to a structured ApiError
  ApiError handleError(dynamic error) {
    if (error is DioException) {
      final response = error.response;
      final statusCode = response?.statusCode ?? 500;
      final data = response?.data;

      if (response != null && data is Map<String, dynamic>) {
        return ApiError.fromResponse(statusCode, data);
      }

      if (response != null) {
        return ApiError(
          statusCode: statusCode,
          errorCode: 'HTTP_ERROR',
          message:
              'The server returned an error (HTTP $statusCode). Please try again.',
        );
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return ApiError(
          statusCode: 408,
          errorCode: 'NETWORK_TIMEOUT',
          message:
              'Connection timed out. Please check your internet connection.',
        );
      }

      if (error.type == DioExceptionType.connectionError) {
        return ApiError(
          statusCode: 503,
          errorCode: 'NETWORK_UNAVAILABLE',
          message: 'Unable to reach the server. Please verify your connection.',
        );
      }

      return ApiError(
        statusCode: statusCode,
        errorCode: 'NETWORK_ERROR',
        message: 'A network error occurred. Please try again.',
      );
    }

    if (error is ApiError) {
      return error;
    }

    return ApiError(
      statusCode: 500,
      errorCode: 'INTERNAL_ERROR',
      message: error.toString(),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw handleError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw handleError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw handleError(e);
    }
  }
}
