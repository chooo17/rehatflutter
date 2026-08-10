import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/utils/formatters.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Menguji parsing model amplop alokasi (overview & buku besar): kontrak API
/// aktual (lihat brief Task 6) — banyak field bertambah selama Task 3-5,
/// termasuk `guards` camelCase, saldo boleh negatif, dan paginasi keyset
/// komposit pada ledger.

void main() {
  group('BucketBalances.fromJson', () {
    test('membaca semua bucket', () {
      final b = BucketBalances.fromJson({
        'restock': 1000000,
        'operational': 500000,
        'personal': 200000,
        'scaling': 300000,
        'emergency': 400000,
      });
      expect(b.restock, 1000000);
      expect(b.operational, 500000);
      expect(b.personal, 200000);
      expect(b.scaling, 300000);
      expect(b.emergency, 400000);
    });

    test('saldo negatif terbaca apa adanya, TIDAK di-clamp ke 0', () {
      final b = BucketBalances.fromJson({
        'restock': -150000,
        'personal': -1,
      });
      expect(b.restock, -150000);
      expect(b.personal, -1);
    });

    test('field hilang default ke 0', () {
      final b = BucketBalances.fromJson(const {});
      expect(b.restock, 0);
      expect(b.operational, 0);
      expect(b.personal, 0);
      expect(b.scaling, 0);
      expect(b.emergency, 0);
    });
  });

  group('FinanceGuards.fromJson', () {
    test('membaca rambu camelCase', () {
      final g = FinanceGuards.fromJson({
        'breakEvenDaily': 850000,
        'runwayDays': 45,
        'emergencyPct': 60,
        'personalWithdrawBlocked': true,
        'emergencyReached': false,
      });
      expect(g.breakEvenDaily, 850000);
      expect(g.runwayDays, 45);
      expect(g.emergencyPct, 60);
      expect(g.personalWithdrawBlocked, isTrue);
      expect(g.emergencyReached, isFalse);
    });

    test('field hilang jatuh ke 0/false', () {
      final g = FinanceGuards.fromJson(const {});
      expect(g.breakEvenDaily, 0);
      expect(g.runwayDays, 0);
      expect(g.emergencyPct, 0);
      expect(g.personalWithdrawBlocked, isFalse);
      expect(g.emergencyReached, isFalse);
    });
  });

  group('FinanceSettings.fromJson', () {
    test('membaca pengaturan alokasi', () {
      final s = FinanceSettings.fromJson({
        'pct_restock': 0.4,
        'operational_daily': 150000,
        'emergency_target': 20000000,
        'started_on': '2026-01-01',
      });
      expect(s.pctRestock, 0.4);
      expect(s.operationalDaily, 150000);
      expect(s.emergencyTarget, 20000000);
      expect(s.startedOn, '2026-01-01');
    });

    test('field hilang jatuh ke nilai aman', () {
      final s = FinanceSettings.fromJson(const {});
      expect(s.pctRestock, 0);
      expect(s.operationalDaily, 0);
      expect(s.emergencyTarget, 0);
      expect(s.startedOn, isNull);
    });
  });

  group('FinanceOverview.fromJson', () {
    test('membaca respons lengkap', () {
      final o = FinanceOverview.fromJson({
        'balances': {
          'restock': 1000000,
          'operational': 500000,
          'personal': 200000,
          'scaling': 300000,
          'emergency': 400000,
        },
        'guards': {
          'breakEvenDaily': 850000,
          'runwayDays': 45,
          'emergencyPct': 60,
          'personalWithdrawBlocked': false,
          'emergencyReached': false,
        },
        'settings': {
          'pct_restock': 0.4,
          'operational_daily': 150000,
          'emergency_target': 20000000,
          'started_on': '2026-01-01',
        },
        'last_allocated_date': '2026-08-09',
        'basis': 'previous',
        'basis_month': '2026-07',
        'insufficient_data': false,
        'margin_non_positive': false,
        'variable_expenses_unavailable': false,
        'missing_allocation_dates': ['2026-08-05', '2026-08-06'],
        'missing_allocation_count': 2,
      });
      expect(o.balances.restock, 1000000);
      expect(o.guards.runwayDays, 45);
      expect(o.settings.emergencyTarget, 20000000);
      expect(o.lastAllocatedDate, '2026-08-09');
      expect(o.basis, 'previous');
      expect(o.basisMonth, '2026-07');
      expect(o.insufficientData, isFalse);
      expect(o.marginNonPositive, isFalse);
      expect(o.variableExpensesUnavailable, isFalse);
      expect(o.missingAllocationDates, ['2026-08-05', '2026-08-06']);
      expect(o.missingAllocationCount, 2);
    });

    test('saldo negatif di dalam overview terbaca apa adanya', () {
      final o = FinanceOverview.fromJson({
        'balances': {'restock': -50000},
      });
      expect(o.balances.restock, -50000);
    });

    test('field flag hilang → false, list hilang → kosong, bukan crash', () {
      final o = FinanceOverview.fromJson(const {});
      expect(o.insufficientData, isFalse);
      expect(o.marginNonPositive, isFalse);
      expect(o.variableExpensesUnavailable, isFalse);
      expect(o.missingAllocationDates, isEmpty);
      expect(o.missingAllocationCount, 0);
      expect(o.lastAllocatedDate, isNull);
      expect(o.basis, '');
      expect(o.basisMonth, '');
    });

    test('insufficient_data true dengan breakEvenDaily 0 TIDAK berarti target tercapai', () {
      final o = FinanceOverview.fromJson({
        'guards': {'breakEvenDaily': 0},
        'insufficient_data': true,
      });
      expect(o.guards.breakEvenDaily, 0);
      expect(o.insufficientData, isTrue);
    });

    test('missing_allocation_count bisa lebih besar dari panjang list (dibatasi 60)', () {
      final o = FinanceOverview.fromJson({
        'missing_allocation_dates': ['2026-08-01'],
        'missing_allocation_count': 75,
      });
      expect(o.missingAllocationDates.length, 1);
      expect(o.missingAllocationCount, 75);
    });
  });

  group('LedgerEntry.fromJson', () {
    test('membaca satu baris buku besar', () {
      final e = LedgerEntry.fromJson({
        'id': 'l1',
        'bucket': 'restock',
        'direction': 'in',
        'source': 'allocation',
        'amount': 400000,
        'note': 'Alokasi harian',
        'ref_date': '2026-08-09',
        'created_at': '2026-08-09T03:00:00.000Z',
        'created_by': 'u1',
      });
      expect(e.id, 'l1');
      expect(e.bucket, 'restock');
      expect(e.direction, 'in');
      expect(e.source, 'allocation');
      expect(e.amount, 400000);
      expect(e.note, 'Alokasi harian');
      expect(e.refDate, '2026-08-09');
      expect(e.createdBy, 'u1');
      // 03:00 UTC → 10:00 WIB.
      expect(Formatters.toWib(e.createdAt).hour, 10);
    });

    test('created_at UTC diparse benar walau tanpa penanda zona eksplisit di tampilan', () {
      final e = LedgerEntry.fromJson({
        'id': 'l2',
        'created_at': '2026-08-09T20:00:00.000Z',
      });
      // 20:00 UTC → 03:00 WIB keesokan harinya.
      final wib = Formatters.toWib(e.createdAt);
      expect(wib.hour, 3);
      expect(wib.day, 10);
    });

    test('created_at TANPA penanda zona tetap ditafsirkan UTC (bukan waktu lokal perangkat)', () {
      final e = LedgerEntry.fromJson({
        'id': 'l4',
        // Tanpa 'Z' / offset — kalau helper parsing salah, DateTime.parse
        // akan membacanya sebagai waktu lokal perangkat, bukan UTC.
        'created_at': '2026-08-09T03:00:00.000',
      });
      expect(e.createdAt.isUtc, isTrue);
      expect(Formatters.toWib(e.createdAt).hour, 10);
    });

    test('amount negatif (penarikan) terbaca apa adanya', () {
      final e = LedgerEntry.fromJson({'id': 'l3', 'amount': -250000});
      expect(e.amount, -250000);
    });

    test('field hilang jatuh ke nilai aman', () {
      final e = LedgerEntry.fromJson(const {});
      expect(e.id, '');
      expect(e.bucket, '');
      expect(e.direction, '');
      expect(e.source, '');
      expect(e.amount, 0);
      expect(e.note, '');
      expect(e.refDate, '');
      expect(e.createdBy, isNull);
    });
  });

  group('LedgerPage.fromJson', () {
    test('membaca daftar + kursor halaman berikutnya', () {
      final p = LedgerPage.fromJson({
        'items': [
          {'id': 'l1', 'bucket': 'restock', 'amount': 100000},
          {'id': 'l2', 'bucket': 'restock', 'amount': 200000},
        ],
        'has_more': true,
        'next_before': '2026-08-09T03:00:00.000Z',
        'next_before_id': 'l2',
      });
      expect(p.items.length, 2);
      expect(p.hasMore, isTrue);
      expect(p.nextBefore, '2026-08-09T03:00:00.000Z');
      expect(p.nextBeforeId, 'l2');
    });

    test('has_more false & tanpa kursor di halaman terakhir', () {
      final p = LedgerPage.fromJson({
        'items': [
          {'id': 'l1'},
        ],
        'has_more': false,
      });
      expect(p.hasMore, isFalse);
      expect(p.nextBefore, isNull);
      expect(p.nextBeforeId, isNull);
    });

    test('respons kosong menghasilkan daftar kosong, bukan exception', () {
      final p = LedgerPage.fromJson(const {});
      expect(p.items, isEmpty);
      expect(p.hasMore, isFalse);
    });
  });

  group('FinanceRepository.fetchLedger cursor pairing', () {
    test('before tanpa before_id (atau sebaliknya) ditolak di sisi klien', () {
      expect(
        () => FinanceRepository.validateCursor(before: '2026-08-09T03:00:00.000Z', beforeId: null),
        throwsArgumentError,
      );
      expect(
        () => FinanceRepository.validateCursor(before: null, beforeId: 'l2'),
        throwsArgumentError,
      );
    });

    test('keduanya null atau keduanya terisi diterima', () {
      expect(() => FinanceRepository.validateCursor(before: null, beforeId: null), returnsNormally);
      expect(
        () => FinanceRepository.validateCursor(
            before: '2026-08-09T03:00:00.000Z', beforeId: 'l2'),
        returnsNormally,
      );
    });
  });
}
