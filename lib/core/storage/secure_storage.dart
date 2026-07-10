import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan aman untuk token JWT & data sensitif.
///
/// Menggunakan Keychain (iOS) dan EncryptedSharedPreferences (Android).
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kThemeMode = 'theme_mode';

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<bool> hasToken() async => (await readAccessToken())?.isNotEmpty ?? false;

  /// Menyimpan preferensi mode tema (persist lintas login).
  Future<void> saveThemeMode(ThemeMode mode) =>
      _storage.write(key: _kThemeMode, value: mode.name);

  Future<ThemeMode?> readThemeMode() async {
    switch (await _storage.read(key: _kThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  /// Hanya menghapus token (preferensi tema sengaja dipertahankan saat logout).
  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}

/// Provider global untuk [SecureStorage].
final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());
