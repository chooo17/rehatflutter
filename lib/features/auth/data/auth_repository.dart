import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';

/// Hasil register: backend mengirim OTP, belum membuat akun.
class RegisterResult {
  const RegisterResult(
      {required this.otpToken, this.expiresIn = 300, this.otpSent = true});

  /// Token sementara untuk memverifikasi OTP.
  final String otpToken;

  /// Masa berlaku OTP dalam detik.
  final int expiresIn;

  /// `false` bila server GAGAL mengirim OTP otomatis (gateway rapuh) — UI perlu
  /// memberi tahu pengguna & mengarahkan ke "Kirim ulang".
  final bool otpSent;
}

/// Hasil kirim-ulang OTP.
class ResendResult {
  const ResendResult({required this.otpToken, this.otpSent = true});
  final String otpToken;
  final bool otpSent;
}

/// Hasil autentikasi (verify-otp / login): token tersimpan + status profil.
class AuthResult {
  const AuthResult({this.user, this.isProfileComplete = false});

  final UserModel? user;
  final bool isProfileComplete;
}

/// Akses jaringan untuk autentikasi (custom JWT backend, bukan Supabase Auth).
///
/// Alur register: register(identifier) → OTP dikirim → verifyOtp → token.
/// Backend membungkus respons dalam `{ success, data, message }`.
class AuthRepository {
  AuthRepository({required DioClient client, required SecureStorage storage})
      : _client = client,
        _storage = storage;

  final DioClient _client;
  final SecureStorage _storage;

  /// Mendaftar dengan nomor HP. Mengembalikan `otpToken` untuk verifikasi.
  Future<RegisterResult> register({
    required String phone,
    required String password,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {
        'identifier': phone,
        'identifier_type': 'phone',
        'password': password,
      },
    );
    final data = _unwrap(res.data);
    final otpToken = (data['otpToken'] ?? data['otp_token'])?.toString();
    if (otpToken == null || otpToken.isEmpty) {
      throw Exception('otpToken tidak ditemukan pada respons server.');
    }
    return RegisterResult(
      otpToken: otpToken,
      expiresIn: _asInt(data['expiresIn'] ?? data['expires_in'], 300),
      // Default true agar kompatibel dgn backend lama yang tak mengirim flag.
      otpSent: (data['otpSent'] ?? data['otp_sent'] ?? true) == true,
    );
  }

  /// Verifikasi kode OTP. Menyimpan token & mengembalikan status profil.
  Future<AuthResult> verifyOtp({
    required String otpToken,
    required String otpCode,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.verifyOtp,
      data: {'otp_token': otpToken, 'otp_code': otpCode},
    );
    final data = _unwrap(res.data);
    await _saveTokensFrom(data);
    return AuthResult(
      isProfileComplete:
          (data['isProfileComplete'] ?? data['is_profile_complete'] ?? false) == true,
    );
  }

  /// Meminta kode OTP baru. Mengembalikan token baru + status kirim.
  Future<ResendResult> resendOtp(String otpToken) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.resendOtp,
      data: {'otp_token': otpToken},
    );
    final data = _unwrap(res.data);
    final newToken = (data['otpToken'] ?? data['otp_token'] ?? otpToken).toString();
    return ResendResult(
      otpToken: newToken,
      otpSent: (data['otpSent'] ?? data['otp_sent'] ?? true) == true,
    );
  }

  /// Minta reset password: backend mengirim OTP ke nomor terdaftar.
  /// Mengembalikan `otpToken` untuk layar reset. `USER_NOT_FOUND` (404) bila
  /// nomor tak terdaftar (di-surface sebagai ApiException oleh DioClient).
  Future<RegisterResult> requestPasswordReset({required String phone}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.forgotPassword,
      data: {'identifier': phone, 'identifier_type': 'phone'},
    );
    final data = _unwrap(res.data);
    final otpToken = (data['otpToken'] ?? data['otp_token'])?.toString();
    if (otpToken == null || otpToken.isEmpty) {
      throw Exception('otpToken tidak ditemukan pada respons server.');
    }
    return RegisterResult(
      otpToken: otpToken,
      expiresIn: _asInt(data['expiresIn'] ?? data['expires_in'], 300),
      otpSent: (data['otpSent'] ?? data['otp_sent'] ?? true) == true,
    );
  }

  /// Set password baru setelah OTP reset terverifikasi.
  Future<void> resetPassword({
    required String otpToken,
    required String otpCode,
    required String newPassword,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.resetPassword,
      data: {
        'otp_token': otpToken,
        'otp_code': otpCode,
        'new_password': newPassword,
      },
    );
  }

  /// Masuk dengan nomor HP (atau email) sebagai identifier.
  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {'identifier': phone, 'password': password},
    );
    final data = _unwrap(res.data);
    await _saveTokensFrom(data);

    UserModel? user;
    final userJson = data['user'];
    if (userJson is Map) {
      user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
    }
    return AuthResult(
      user: user,
      isProfileComplete: user?.isProfileComplete ??
          ((data['user'] is Map &&
                  (data['user']['is_profile_complete'] ?? false) == true)),
    );
  }

  /// Mengambil profil pengguna saat ini (`GET /users/me`).
  Future<UserModel> me() async {
    final res = await _client.get<Map<String, dynamic>>(ApiConstants.me);
    final data = _unwrap(res.data);
    return UserModel.fromJson(data);
  }

  /// Melengkapi / memperbarui profil (`PUT /users/me`).
  Future<UserModel> updateProfile({
    required String name,
    String? birthdate,
  }) async {
    final res = await _client.put<Map<String, dynamic>>(
      ApiConstants.updateProfile,
      data: {
        'name': name,
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
      },
    );
    final data = _unwrap(res.data);
    return UserModel.fromJson(data);
  }

  /// Mengunggah foto profil (multipart). Mengembalikan URL avatar baru.
  Future<String> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res =
        await _client.post<Map<String, dynamic>>(ApiConstants.avatar, data: form);
    final data = _unwrap(res.data);
    final url = (data['avatar_url'] ?? data['avatarUrl'])?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('URL avatar tidak ditemukan pada respons.');
    }
    return url;
  }

  Future<void> logout() async {
    final refresh = await _storage.readRefreshToken();
    try {
      await _client.post<dynamic>(
        ApiConstants.logout,
        data: {if (refresh != null) 'refresh_token': refresh},
      );
    } catch (_) {
      // Abaikan kegagalan jaringan saat logout — yang penting token lokal hilang.
    }
    await _storage.clear();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Membuka pembungkus `{ success, data, message }` → mengembalikan `data`.
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return const {};
    final inner = body['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return body;
  }

  Future<void> _saveTokensFrom(Map<String, dynamic> data) async {
    final accessToken =
        (data['accessToken'] ?? data['access_token'] ?? data['token'])?.toString();
    final refreshToken =
        (data['refreshToken'] ?? data['refresh_token'])?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Token tidak ditemukan pada respons server.');
    }
    await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: ref.watch(dioClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});
