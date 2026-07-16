/// Satu printer Bluetooth ter-pairing.
class BtPrinter {
  const BtPrinter(this.name, this.address);
  final String name;
  final String address;
}

/// Abstraksi printer thermal. Implementasi nyata hanya di Android
/// (printer_bridge_mobile.dart); di web memakai stub no-op agar build web aman.
abstract class PrinterBridge {
  /// `false` di web / platform tanpa dukungan Bluetooth thermal.
  bool get supported;

  /// Minta izin Bluetooth (Android 12+). `true` bila diberikan / tak diperlukan.
  Future<bool> ensurePermissions();

  /// Daftar printer yang sudah di-pairing di pengaturan Bluetooth HP.
  Future<List<BtPrinter>> paired();

  /// Sambungkan ke printer berdasarkan alamat MAC.
  Future<bool> connect(String address);

  /// Status koneksi saat ini.
  Future<bool> connected();

  /// Putuskan koneksi.
  Future<void> disconnect();

  /// Cetak struk: [logoBytes] (PNG, opsional) dicetak di TENGAH paling atas,
  /// lalu [text] (sudah ter-render dari template), lalu potong kertas.
  /// Mengembalikan `true` bila berhasil dikirim ke printer.
  Future<bool> printReceipt(String text, {List<int>? logoBytes});
}
