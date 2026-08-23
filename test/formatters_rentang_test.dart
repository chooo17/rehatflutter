import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rehat_app/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('Formatters.rentang', () {
    test('tahun sama -> tahun awal disembunyikan, en dash memisahkan', () {
      // 2026-08-22T17:00:00Z + 7 jam = 2026-08-23 00:00 WIB.
      final start = DateTime.utc(2026, 8, 22, 17);
      // 2026-08-29T16:59:59.999Z + 7 jam = 2026-08-29 23:59:59.999 WIB.
      final end = DateTime.utc(2026, 8, 29, 16, 59, 59, 999);

      expect(Formatters.rentang(start, end), '23 Agu – 29 Agu 2026');
    });

    test('tahun beda -> tahun awal ikut ditampilkan', () {
      // 2025-12-29T17:00:00Z + 7 jam = 2025-12-30 00:00 WIB.
      final start = DateTime.utc(2025, 12, 29, 17);
      // 2026-01-02T16:59:59.999Z + 7 jam = 2026-01-02 23:59:59.999 WIB.
      final end = DateTime.utc(2026, 1, 2, 16, 59, 59, 999);

      expect(Formatters.rentang(start, end), '30 Des 2025 – 2 Jan 2026');
    });
  });
}
