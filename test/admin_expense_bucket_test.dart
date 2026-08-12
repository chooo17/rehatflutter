import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/admin/application/expense_bucket.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';

/// Menguji logika penyajian & validasi MURNI pemilihan pos (amplop) saat
/// mencatat pengeluaran (`expense_bucket.dart`) — tanpa merender widget apa
/// pun. Fokus utama: default HARUS 'restock' (perilaku lama), pos tak
/// dikenal HARUS jatuh ke default (bukan diteruskan mentah ke backend), dan
/// `ExpenseItem.fromJson` HARUS memparse `bucket` secara defensif.
void main() {
  group('defaultExpenseBucket', () {
    test('adalah restock', () {
      expect(defaultExpenseBucket, 'restock');
    });
  });

  group('expenseBucketOptions', () {
    test('memuat tepat 5 pos dalam urutan yang benar', () {
      expect(expenseBucketOptions,
          ['restock', 'operational', 'personal', 'scaling', 'emergency']);
    });
  });

  group('isValidExpenseBucket', () {
    test('true untuk kelima pos yang dikenal', () {
      for (final b in expenseBucketOptions) {
        expect(isValidExpenseBucket(b), isTrue, reason: b);
      }
    });

    test('false untuk kode tak dikenal', () {
      expect(isValidExpenseBucket('lain-lain'), isFalse);
      expect(isValidExpenseBucket(''), isFalse);
      expect(isValidExpenseBucket('Restock'), isFalse); // case-sensitive
    });
  });

  group('resolveExpenseBucket', () {
    test('meneruskan pos valid apa adanya', () {
      expect(resolveExpenseBucket('operational'), 'operational');
      expect(resolveExpenseBucket('emergency'), 'emergency');
    });

    test('null jatuh ke default', () {
      expect(resolveExpenseBucket(null), defaultExpenseBucket);
    });

    test('kode tak dikenal jatuh ke default (jaring pengaman)', () {
      expect(resolveExpenseBucket('bukan-pos'), defaultExpenseBucket);
    });
  });

  group('expenseBucketLabel', () {
    test('memetakan kelima pos ke label Indonesia', () {
      expect(expenseBucketLabel('restock'), 'Restock');
      expect(expenseBucketLabel('operational'), 'Operasional');
      expect(expenseBucketLabel('personal'), 'Pribadi');
      expect(expenseBucketLabel('scaling'), 'Scaling');
      expect(expenseBucketLabel('emergency'), 'Dana Darurat');
    });

    test('kode tak dikenal ditampilkan apa adanya (fallback), bukan disembunyikan', () {
      expect(expenseBucketLabel('kode-aneh'), 'kode-aneh');
    });
  });

  group('ExpenseItem.fromJson — parsing bucket', () {
    test('mengambil bucket dari respons', () {
      final item = ExpenseItem.fromJson({
        'id': '1',
        'amount': 5000,
        'bucket': 'operational',
        'spent_at': '2026-08-01T00:00:00Z',
      });
      expect(item.bucket, 'operational');
    });

    test('default ke restock bila field bucket tidak ada (respons lama)', () {
      final item = ExpenseItem.fromJson({
        'id': '1',
        'amount': 5000,
        'spent_at': '2026-08-01T00:00:00Z',
      });
      expect(item.bucket, 'restock');
    });

    test('default ke restock bila bucket kosong', () {
      final item = ExpenseItem.fromJson({
        'id': '1',
        'amount': 5000,
        'bucket': '',
        'spent_at': '2026-08-01T00:00:00Z',
      });
      expect(item.bucket, 'restock');
    });
  });
}
