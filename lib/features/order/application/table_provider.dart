import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Baca nomor meja dari URL saat scan QR meja: `…?table=5`.
/// Di web, `Uri.base` memuat query string halaman. Di APK biasanya kosong
/// (QR meja membuka web app, bukan aplikasi terpasang) — mengembalikan null.
String? readTableFromUrl() {
  try {
    final t = Uri.base.queryParameters['table'];
    if (t == null) return null;
    final s = t.trim();
    if (s.isEmpty) return null;
    return s.length > 16 ? s.substring(0, 16) : s;
  } catch (_) {
    return null;
  }
}

/// Nomor meja aktif (dari QR). null bila pelanggan tak datang lewat QR meja.
/// StateProvider agar bisa di-clear setelah checkout bila diperlukan.
final tableNumberProvider =
    StateProvider<String?>((ref) => readTableFromUrl());
