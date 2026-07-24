import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Menyisipkan token JWT ke setiap request, dan saat menerima 401 mencoba
/// **memperbarui token** via `/auth/refresh` lalu mengulang request asli.
/// Jika refresh gagal (refresh token kedaluwarsa/dicabut), sesi dibersihkan
/// dan [onUnauthorized] dipanggil (logout).
///
/// Auth menggunakan custom JWT backend (bukan Supabase Auth).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorage storage,
    required Dio dio,
    this.onUnauthorized,
  })  : _storage = storage,
        _dio = dio,
        // Dio terpisah tanpa interceptor agar refresh tidak memicu rekursi.
        _refreshDio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout:
              const Duration(milliseconds: ApiConstants.connectTimeoutMs),
          receiveTimeout:
              const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
          contentType: 'application/json',
        ));

  final SecureStorage _storage;
  final Dio _dio;
  final Dio _refreshDio;

  /// Dipanggil saat sesi benar-benar berakhir (refresh gagal).
  final Future<void> Function()? onUnauthorized;

  /// Menjaga agar hanya ada satu proses refresh meski banyak request 401 bersamaan.
  Completer<bool>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Endpoint pra-auth (login/register/refresh/verify/resend) tak boleh
    // membawa bearer token lama — secara semantik salah & tak perlu.
    // `/auth/logout` DIKECUALIKAN dari daftar ini karena butuh token untuk
    // menutup sesi di server.
    const preAuthPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/refresh',
      '/auth/verify-otp',
      '/auth/resend-otp',
    ];
    final isPreAuth = preAuthPaths.any(options.path.contains);
    if (!isPreAuth) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final path = err.requestOptions.path;
    // Jangan coba refresh untuk endpoint auth (login/refresh/dll) atau bila
    // request ini sudah pernah diulang.
    final isAuthEndpoint = path.contains('/auth/');
    final alreadyRetried = err.requestOptions.extra['__retried__'] == true;

    if (!isUnauthorized || isAuthEndpoint || alreadyRetried) {
      return handler.next(err);
    }

    final refreshed = await _refreshTokens();
    if (!refreshed) {
      await _storage.clear();
      await onUnauthorized?.call();
      return handler.next(err);
    }

    // Ulangi request asli dengan token baru.
    try {
      final token = await _storage.readAccessToken();
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer $token';
      options.extra['__retried__'] = true;
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    } catch (_) {
      return handler.next(err);
    }
  }

  /// Memperbarui token; dedupe agar request 401 bersamaan hanya memicu 1 refresh.
  Future<bool> _refreshTokens() {
    final existing = _refreshCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    _doRefresh().then((ok) {
      _refreshCompleter = null;
      completer.complete(ok);
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final res = await _refreshDio.post<dynamic>(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );
      final body = res.data;
      final data = (body is Map && body['data'] is Map)
          ? Map<String, dynamic>.from(body['data'] as Map)
          : (body is Map ? Map<String, dynamic>.from(body) : const {});

      final accessToken =
          (data['accessToken'] ?? data['access_token'] ?? data['token'])?.toString();
      final newRefresh =
          (data['refreshToken'] ?? data['refresh_token'])?.toString();

      if (accessToken == null || accessToken.isEmpty) return false;
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefresh ?? refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
