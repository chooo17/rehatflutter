import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';

/// Mengelola preferensi mode tema (sistem / terang / gelap) & menyimpannya.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system; // default sampai preferensi tersimpan dimuat
  }

  Future<void> _load() async {
    final saved = await ref.read(secureStorageProvider).readThemeMode();
    if (saved != null) state = saved;
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(secureStorageProvider).saveThemeMode(mode);
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
