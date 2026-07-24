/// Skala radius sudut terpusat.
///
/// Sebelumnya tiap layar menebak angka sendiri (14/16/18/20/22) sehingga
/// komponen serupa tampil sedikit berbeda. Pakai token ini untuk konsistensi;
/// adopsi bertahap di call-site yang disentuh.
class AppRadius {
  AppRadius._();

  /// Chip kecil, badge.
  static const double sm = 12;

  /// Kartu/field standar.
  static const double md = 16;

  /// Kartu besar, sheet, header.
  static const double lg = 20;

  /// Kontainer paling menonjol (hero card).
  static const double xl = 24;
}
