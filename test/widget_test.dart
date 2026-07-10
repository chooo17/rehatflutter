// Tes unit dasar untuk util format mata uang Rupiah.
//
// Catatan: smoke test penuh aplikasi (RehatApp) memerlukan inisialisasi
// secure storage & jaringan, jadi di sini kita uji util murni yang stabil.

import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/utils/formatters.dart';

void main() {
  group('Formatters.rupiah', () {
    test('memformat ribuan dengan pemisah titik', () {
      expect(Formatters.rupiah(25000), 'Rp 25.000');
    });

    test('memformat nol', () {
      expect(Formatters.rupiah(0), 'Rp 0');
    });

    test('tanpa angka desimal', () {
      expect(Formatters.rupiah(15500), 'Rp 15.500');
    });
  });
}
