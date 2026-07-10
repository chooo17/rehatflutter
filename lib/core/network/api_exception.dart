import 'package:dio/dio.dart';

/// Exception terstandar untuk error API yang siap ditampilkan ke pengguna
/// (pesan dalam Bahasa Indonesia).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.data});

  final String message;
  final int? statusCode;

  /// Kode error dari backend (mis. `SPIN_ALREADY_USED_TODAY`), bila ada.
  final String? code;
  final dynamic data;

  /// Apakah error karena sesi tidak valid / token kadaluarsa.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode/$code): $message';

  /// Memetakan [DioException] menjadi pesan ramah pengguna.
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException('Koneksi timeout. Coba lagi sebentar.');
      case DioExceptionType.connectionError:
        return ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
      case DioExceptionType.cancel:
        return ApiException('Permintaan dibatalkan.');
      case DioExceptionType.badCertificate:
        return ApiException('Sertifikat server tidak valid.');
      case DioExceptionType.badResponse:
        return ApiException(
          _messageFromResponse(e.response),
          statusCode: e.response?.statusCode,
          code: _codeFromResponse(e.response),
          data: e.response?.data,
        );
      case DioExceptionType.unknown:
        return ApiException('Terjadi kesalahan. Silakan coba lagi.');
    }
  }

  static String _messageFromResponse(Response? response) {
    final data = response?.data;
    if (data is Map) {
      // Envelope backend: { success:false, error:{ code, message } }.
      final err = data['error'];
      if (err is Map && err['message'] is String && (err['message'] as String).isNotEmpty) {
        return err['message'] as String;
      }
      // Bentuk lain: { message: "..." } atau { error: "..." }.
      final msg = data['message'] ?? (err is String ? err : null);
      if (msg is String && msg.isNotEmpty) return msg;
    }
    final code = response?.statusCode;
    if (code == 401) return 'Sesi berakhir. Silakan masuk kembali.';
    if (code == 403) return 'Anda tidak memiliki akses untuk tindakan ini.';
    if (code == 404) return 'Data tidak ditemukan.';
    if (code != null && code >= 500) return 'Server sedang bermasalah. Coba lagi nanti.';
    return 'Terjadi kesalahan ($code).';
  }

  static String? _codeFromResponse(Response? response) {
    final data = response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['code'] is String) return err['code'] as String;
      if (data['code'] is String) return data['code'] as String;
    }
    return null;
  }
}
