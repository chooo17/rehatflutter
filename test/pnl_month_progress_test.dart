import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/finance/presentation/profit_loss_screen.dart';

/// Menguji fungsi murni [monthProgress]: penanda "bulan berjalan" di layar
/// Laba Rugi. Harus null untuk bulan lampau/depan, dan menghitung hari
/// berjalan yang benar (termasuk Februari kabisat/non-kabisat) untuk bulan
/// yang sedang berjalan (WIB).
void main() {
  group('monthProgress', () {
    test('bulan berjalan: 10 Agustus dari bulan Agustus -> 10 dari 31 hari', () {
      final displayed = DateTime(2026, 8);
      final todayWib = DateTime(2026, 8, 10);
      final info = monthProgress(displayed, todayWib);
      expect(info, isNotNull);
      expect(info!.daysElapsed, 10);
      expect(info.daysInMonth, 31);
    });

    test('bulan lampau -> null', () {
      final displayed = DateTime(2026, 7);
      final todayWib = DateTime(2026, 8, 10);
      expect(monthProgress(displayed, todayWib), isNull);
    });

    test('bulan depan -> null', () {
      final displayed = DateTime(2026, 9);
      final todayWib = DateTime(2026, 8, 10);
      expect(monthProgress(displayed, todayWib), isNull);
    });

    test('bulan lampau tahun berbeda -> null', () {
      final displayed = DateTime(2025, 8);
      final todayWib = DateTime(2026, 8, 10);
      expect(monthProgress(displayed, todayWib), isNull);
    });

    test('Februari kabisat (2028) -> 29 hari', () {
      final displayed = DateTime(2028, 2);
      final todayWib = DateTime(2028, 2, 15);
      final info = monthProgress(displayed, todayWib);
      expect(info, isNotNull);
      expect(info!.daysElapsed, 15);
      expect(info.daysInMonth, 29);
    });

    test('Februari non-kabisat (2026) -> 28 hari', () {
      final displayed = DateTime(2026, 2);
      final todayWib = DateTime(2026, 2, 1);
      final info = monthProgress(displayed, todayWib);
      expect(info, isNotNull);
      expect(info!.daysElapsed, 1);
      expect(info.daysInMonth, 28);
    });

    test('hari terakhir bulan (31 dari 31) tetap dianggap bulan berjalan', () {
      final displayed = DateTime(2026, 8);
      final todayWib = DateTime(2026, 8, 31);
      final info = monthProgress(displayed, todayWib);
      expect(info, isNotNull);
      expect(info!.daysElapsed, 31);
      expect(info.daysInMonth, 31);
    });
  });
}
