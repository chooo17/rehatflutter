import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografi Rehat Coffeehouse.
///
/// - Display: Cormorant Garamond (serif, weight 600/700)
/// - Body: Inter (weight 400/500/600)
///
/// Font dimuat runtime via `google_fonts`, jadi tidak perlu mendaftarkan
/// file font di pubspec.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _display(double size, FontWeight weight, Color color) {
    return GoogleFonts.cormorantGaramond(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.1,
    );
  }

  static TextStyle _body(double size, FontWeight weight, Color color) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.45,
    );
  }

  // Getter (bukan field) agar warna ikut menyesuaikan tema aktif tiap build.

  // Display (Cormorant Garamond) ----------------------------------------

  static TextStyle get displayLarge => _display(40, FontWeight.w700, AppColors.textPrimary);
  static TextStyle get displayMedium => _display(32, FontWeight.w700, AppColors.textPrimary);
  static TextStyle get displaySmall => _display(26, FontWeight.w600, AppColors.textPrimary);
  static TextStyle get headline => _display(22, FontWeight.w600, AppColors.textPrimary);

  // Body (Inter) ---------------------------------------------------------

  static TextStyle get titleLarge => _body(18, FontWeight.w600, AppColors.textPrimary);
  static TextStyle get titleMedium => _body(16, FontWeight.w600, AppColors.textPrimary);
  static TextStyle get bodyLarge => _body(16, FontWeight.w400, AppColors.textPrimary);
  static TextStyle get bodyMedium => _body(14, FontWeight.w400, AppColors.textPrimary);
  static TextStyle get bodySmall => _body(12, FontWeight.w400, AppColors.textSecondary);
  static TextStyle get label => _body(14, FontWeight.w600, AppColors.textPrimary);
  static TextStyle get button => _body(15, FontWeight.w600, AppColors.textOnDark);
  static TextStyle get caption => _body(12, FontWeight.w500, AppColors.textSecondary);
}
