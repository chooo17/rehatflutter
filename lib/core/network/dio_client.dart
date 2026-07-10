import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Pembungkus tipis di atas [Dio] dengan base URL, interceptor JWT,
/// dan konversi error ke [ApiException].
class DioClient {
  DioClient({
    required SecureStorage storage,
    this.onUnauthorized,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
            receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
            contentType: 'application/json',
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        dio: _dio,
        // Membaca field mutable agar bisa di-set setelah konstruksi
        // (mis. oleh AuthController) tanpa ketergantungan melingkar.
        onUnauthorized: () async => onUnauthorized?.call(),
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  final Dio _dio;

  /// Dipanggil saat sesi berakhir (refresh token gagal). Bisa di-set ulang
  /// oleh lapisan auth untuk memicu logout/redirect.
  Future<void> Function()? onUnauthorized;

  Dio get raw => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _guard(() => _dio.get<T>(path, queryParameters: query));
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    return _guard(() => _dio.post<T>(path, data: data, queryParameters: query));
  }

  Future<Response<T>> put<T>(String path, {Object? data}) {
    return _guard(() => _dio.put<T>(path, data: data));
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _guard(() => _dio.patch<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path, {Object? data}) {
    return _guard(() => _dio.delete<T>(path, data: data));
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Provider [DioClient].
///
/// Catatan: `onUnauthorized` di-set di lapisan auth controller agar bisa
/// memicu logout/redirect tanpa membuat ketergantungan melingkar.
final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return DioClient(storage: storage);
});
