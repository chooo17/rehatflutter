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

  /// Format tanggal menjadi "26 Jun 2026".
  static String tanggal(DateTime date) =>
      DateFormat('d MMM yyyy', 'id_ID').format(date);

  /// Format tanggal & jam menjadi "26 Jun 2026, 14:30".
  static String tanggalJam(DateTime date) =>
      DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(date);
}
