/// Konfigurasi build waktu-kompilasi.
///
/// Dipasangkan dengan flavor Android (`customer`/`admin`). Build pelanggan
/// mengirim `--dart-define=ADMIN_BUILD=false` sehingga seluruh UI admin (tab
/// Laporan, menu admin di Profil, pengaturan printer) tersembunyi. Default
/// `true` agar `flutter run` biasa saat pengembangan tetap menampilkan semua.
class AppConfig {
  AppConfig._();

  /// Apakah build ini menyertakan fitur admin/kasir.
  static const bool isAdminBuild =
      bool.fromEnvironment('ADMIN_BUILD', defaultValue: true);
}
