import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';
import '../data/auth_repository.dart';

/// Status sesi autentikasi. `guest` = menjelajah menu tanpa login.
enum AuthStatus { unknown, authenticated, unauthenticated, guest }

/// State autentikasi yang dipantau router & UI.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserModel? user;

  /// Sedang memproses aksi auth (untuk indikator tombol).
  final bool isSubmitting;

  /// Pesan error terakhir (Bahasa Indonesia) untuk ditampilkan ke pengguna.
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Sedang menjelajah sebagai tamu (tanpa login).
  bool get isGuest => status == AuthStatus.guest;

  /// Apakah profil pengguna sudah lengkap (punya nama).
  bool get isProfileComplete => user?.isProfileComplete ?? false;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller autentikasi. Mengelola sesi & aksi register/OTP/login/profil.
class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repo;
  late final SecureStorage _storage;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    _storage = ref.watch(secureStorageProvider);
    // Saat refresh token gagal (sesi benar-benar berakhir), paksa logout.
    ref.read(dioClientProvider).onUnauthorized = _onSessionExpired;
    _restoreSession();
    return const AuthState();
  }

  Future<void> _onSessionExpired() async {
    if (state.status == AuthStatus.unauthenticated) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _restoreSession() async {
    final sw = Stopwatch()..start();
    AuthState next;
    final hasToken = await _storage.hasToken();
    if (!hasToken) {
      next = state.copyWith(status: AuthStatus.unauthenticated);
    } else {
      try {
        final user = await _repo.me();
        next = state.copyWith(status: AuthStatus.authenticated, user: user);
      } catch (_) {
        await _storage.clear();
        next = state.copyWith(status: AuthStatus.unauthenticated);
      }
    }
    // Tahan splash minimal ~1,8 dtk agar animasi logo reveal sempat terlihat.
    final remaining = 1800 - sw.elapsedMilliseconds;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }
    state = next;
  }

  /// Mendaftar. Mengembalikan `otpToken` bila sukses (untuk layar OTP),
  /// atau `null` bila gagal (pesan tersimpan di state).
  Future<String?> register({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await _repo.register(phone: phone, password: password);
      state = state.copyWith(isSubmitting: false);
      return result.otpToken;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(
          isSubmitting: false, errorMessage: 'Gagal mendaftar. Coba lagi.');
      return null;
    }
  }

  /// Verifikasi OTP. Pada sukses, sesi menjadi authenticated.
  Future<bool> verifyOtp({
    required String otpToken,
    required String otpCode,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.verifyOtp(otpToken: otpToken, otpCode: otpCode);
      final user = await _safeMe();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isSubmitting: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
          isSubmitting: false, errorMessage: 'Verifikasi gagal. Coba lagi.');
      return false;
    }
  }

  /// Meminta OTP baru. Mengembalikan token OTP baru atau `null`.
  Future<String?> resendOtp(String otpToken) async {
    try {
      return await _repo.resendOtp(otpToken);
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Masuk dengan nomor HP & kata sandi.
  Future<bool> login({required String phone, required String password}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.login(phone: phone, password: password);
      // Ambil profil lengkap (login hanya mengirim sebagian field user).
      final user = await _safeMe();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isSubmitting: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
          isSubmitting: false, errorMessage: 'Gagal masuk. Coba lagi.');
      return false;
    }
  }

  /// Melengkapi profil (nama + tanggal lahir opsional).
  Future<bool> completeProfile({
    required String name,
    String? birthdate,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final updated = await _repo.updateProfile(name: name, birthdate: birthdate);
      // Gabungkan dengan user lama agar field seperti phone tetap ada.
      final merged = (state.user ?? updated).copyWith(
        name: updated.name,
        birthdate: updated.birthdate,
        isProfileComplete: true,
      );
      state = state.copyWith(user: merged, isSubmitting: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
          isSubmitting: false, errorMessage: 'Gagal menyimpan profil. Coba lagi.');
      return false;
    }
  }

  /// Mengunggah foto profil. Mengembalikan `true` bila sukses.
  Future<bool> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final url = await _repo.uploadAvatar(bytes: bytes, filename: filename);
      final user = state.user?.copyWith(avatarUrl: url);
      if (user != null) state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Gagal mengunggah foto.');
      return false;
    }
  }

  /// Memuat ulang profil dari server (mis. setelah update poin).
  Future<void> refreshUser() async {
    final user = await _safeMe();
    if (user != null) state = state.copyWith(user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Masuk mode tamu — bisa menjelajah menu tanpa login.
  void continueAsGuest() {
    state = const AuthState(status: AuthStatus.guest);
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<UserModel?> _safeMe() async {
    try {
      return await _repo.me();
    } catch (_) {
      return null;
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
