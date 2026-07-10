import 'package:flutter/material.dart';

/// Palet warna Rehat Coffeehouse (dari design system), sadar-tema.
///
/// Warna semantik (latar, permukaan, teks, border) ditentukan oleh
/// [brightness] yang aktif. Pasangan brand `espresso`↔`crema` dibalik
/// bersamaan sehingga setiap kombinasi isian/teks tetap kontras di kedua mode.
///
/// [brightness] di-set sekali per-build oleh `AppTheme.build` / `main`.
class AppColors {
  AppColors._();

  /// Kecerahan aktif — memengaruhi semua getter semantik di bawah.
  static Brightness brightness = Brightness.light;

  static bool get _dark => brightness == Brightness.dark;

  // Aksen tetap (dibaca baik di terang maupun gelap) ---------------------

  /// Aksen hangat — amber.
  static const Color amber = Color(0xFFB47832);
  static const Color amberLight = Color(0xFFD9A766);

  static const Color success = Color(0xFF3E7C5A);
  static const Color error = Color(0xFFB3261E);
  static const Color warning = Color(0xFFC9831F);

  // Pasangan brand yang saling balik ------------------------------------

  /// Warna utama gelap di mode terang; menjadi terang di mode gelap.
  /// Dipakai sebagai teks utama & isian elemen "terpilih"/tombol.
  static Color get espresso =>
      _dark ? const Color(0xFFEDE6D6) : const Color(0xFF0F0907);

  /// Pasangan invers dari [espresso] — teks di atas elemen espresso.
  static Color get crema =>
      _dark ? const Color(0xFF17130F) : const Color(0xFFF0EAD8);

  // Semantik latar & permukaan (base neumorphic) ------------------------

  /// Warna latar untuk [b] tertentu — dipakai a.l. tirai transisi tema.
  static Color backgroundFor(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF23201A) : const Color(0xFFE9E3D5);

  /// Latar utama aplikasi = warna dasar neumorphic. Elemen neumorphic memakai
  /// warna yang sama dan hanya dibedakan oleh bayangan terang/gelap.
  static Color get backgroundLight => backgroundFor(brightness);

  /// Permukaan = warna dasar neumorphic (sama dengan latar).
  static Color get surface => backgroundLight;

  /// Bayangan terang neumorphic (arah sumber cahaya).
  static Color get neuShadowLight =>
      _dark ? const Color(0xFF302B22) : const Color(0xFFFBF6EC);

  /// Bayangan gelap neumorphic.
  static Color get neuShadowDark =>
      _dark ? const Color(0xFF120F0A) : const Color(0xFFCEC5AF);

  static Color get border =>
      _dark ? const Color(0xFF352F27) : const Color(0xFFD8CFBB);

  static Color get divider =>
      _dark ? const Color(0xFF2C2720) : const Color(0xFFDCD3BF);

  // Teks -----------------------------------------------------------------

  /// Teks utama (mengikuti [espresso]).
  static Color get textPrimary => espresso;

  /// Teks sekunder / muted.
  static Color get textSecondary =>
      _dark ? const Color(0xFFA99C8E) : const Color(0xFF6E5F54);

  /// Teks di atas permukaan gelap (mengikuti [crema]).
  static Color get textOnDark => crema;

  /// Aksen amber gelap — di mode gelap dibuat lebih terang agar terbaca.
  static Color get amberDark =>
      _dark ? const Color(0xFFD9A766) : const Color(0xFF8F5E26);
}
