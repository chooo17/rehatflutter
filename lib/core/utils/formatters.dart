import 'package:intl/intl.dart';

/// Util format angka & tanggal (locale Indonesia).
class Formatters {
  Formatters._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format harga menjadi "Rp 25.000".
  static String rupiah(num value) => _rupiah.format(value);

  /// Zona waktu aplikasi: **WIB (UTC+7)**.
  ///
  /// Timestamp dari server berformat UTC, sehingga `DateTime.parse` menghasilkan
  /// DateTime ber-flag UTC. Bila langsung di-`format`, `DateFormat` mencetak jam
  /// UTC — mundur 7 jam dari waktu gerai. Konversi ini memastikan SEMUA tanggal
  /// & jam di aplikasi tampil dalam WIB, apa pun zona waktu perangkat.
  ///
  /// `toUtc()` dipanggil lebih dulu agar aman untuk DateTime lokal maupun UTC.
  static DateTime toWib(DateTime date) =>
      date.toUtc().add(const Duration(hours: 7));

  /// Format tanggal menjadi "26 Jun 2026" (WIB).
  static String tanggal(DateTime date) =>
      DateFormat('d MMM yyyy', 'id_ID').format(toWib(date));

  /// Format tanggal & jam menjadi "26 Jun 2026, 14:30" (WIB).
  static String tanggalJam(DateTime date) =>
      DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(toWib(date));

  /// Format jam saja menjadi "14:30" (WIB).
  static String jam(DateTime date) =>
      DateFormat('HH:mm', 'id_ID').format(toWib(date));
}
