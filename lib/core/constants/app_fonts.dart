/// Nama family font yang di-bundle sebagai aset (didaftarkan di pubspec.yaml).
///
/// Semua font di-bundle lokal (bukan unduhan runtime `google_fonts`) agar teks
/// tampil instan, tetap bekerja offline, dan tak ada "kedip" font saat start.
class AppFonts {
  AppFonts._();

  /// Teks isi & UI (Inter, variable weight 100–900).
  static const String body = 'Inter';

  /// Judul/display serif (Cormorant Garamond, variable weight).
  static const String display = 'Cormorant';

  // Font dekoratif khusus splash screen.
  static const String archivo = 'Archivo';
  static const String archivoBlack = 'ArchivoBlack';
  static const String anton = 'Anton';
}
