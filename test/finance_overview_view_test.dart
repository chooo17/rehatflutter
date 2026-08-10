import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/api_exception.dart';
import 'package:rehat_app/features/finance/application/finance_overview_view.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Menguji logika penyajian MURNI layar Ringkasan Keuangan (Task 7) — tanpa
/// merender widget apa pun. Fokus: kapan angka boleh tampil vs kapan harus
/// diganti peringatan (rambu uang — lihat brief §3), kapan tombol tarik
/// pribadi terkunci, dan ringkasan tanggal bolong.

FinanceOverview _overview({
  BucketBalances balances = const BucketBalances(),
  FinanceGuards guards = const FinanceGuards(),
  FinanceSettings settings = const FinanceSettings(),
  String? lastAllocatedDate,
  String basis = '',
  String basisMonth = '',
  bool insufficientData = false,
  bool marginNonPositive = false,
  bool variableExpensesUnavailable = false,
  List<String> missingAllocationDates = const [],
  int missingAllocationCount = 0,
}) =>
    FinanceOverview(
      balances: balances,
      guards: guards,
      settings: settings,
      lastAllocatedDate: lastAllocatedDate,
      basis: basis,
      basisMonth: basisMonth,
      insufficientData: insufficientData,
      marginNonPositive: marginNonPositive,
      variableExpensesUnavailable: variableExpensesUnavailable,
      missingAllocationDates: missingAllocationDates,
      missingAllocationCount: missingAllocationCount,
    );

void main() {
  group('breakEvenDisplay', () {
    test('insufficientData true → status insufficientData, TANPA angka', () {
      final o = _overview(
        insufficientData: true,
        guards: const FinanceGuards(breakEvenDaily: 0),
      );
      final d = breakEvenDisplay(o);
      expect(d.status, BreakEvenStatus.insufficientData);
    });

    test('marginNonPositive true → status marginNonPositive, bukan "target Rp0"', () {
      final o = _overview(
        marginNonPositive: true,
        guards: const FinanceGuards(breakEvenDaily: 0),
      );
      final d = breakEvenDisplay(o);
      expect(d.status, BreakEvenStatus.marginNonPositive);
    });

    test('insufficientData diperiksa lebih dulu dari marginNonPositive bila keduanya true', () {
      final o = _overview(insufficientData: true, marginNonPositive: true);
      expect(breakEvenDisplay(o).status, BreakEvenStatus.insufficientData);
    });

    test('data cukup & margin positif → status ok dengan angka asli', () {
      final o = _overview(guards: const FinanceGuards(breakEvenDaily: 850000));
      final d = breakEvenDisplay(o);
      expect(d.status, BreakEvenStatus.ok);
      expect(d.amount, 850000);
    });

    test('breakEvenDaily 0 TANPA insufficientData/marginNonPositive tetap status ok (angka nyata)', () {
      final o = _overview(guards: const FinanceGuards(breakEvenDaily: 0));
      final d = breakEvenDisplay(o);
      expect(d.status, BreakEvenStatus.ok);
      expect(d.amount, 0);
    });
  });

  group('runwayWarning', () {
    test('variableExpensesUnavailable true → pesan peringatan tidak null', () {
      final o = _overview(variableExpensesUnavailable: true);
      expect(runwayWarning(o), isNotNull);
    });

    test('variableExpensesUnavailable false → null (tanpa peringatan)', () {
      final o = _overview();
      expect(runwayWarning(o), isNull);
    });
  });

  group('withdrawButtonState', () {
    test('bucket personal + personalWithdrawBlocked true → terkunci dengan alasan', () {
      final s = withdrawButtonState(
        bucket: 'personal',
        guards: const FinanceGuards(personalWithdrawBlocked: true),
      );
      expect(s.enabled, isFalse);
      expect(s.blockedReason, isNotNull);
      expect(s.blockedReason, isNotEmpty);
    });

    test('bucket personal + personalWithdrawBlocked false → aktif', () {
      final s = withdrawButtonState(
        bucket: 'personal',
        guards: const FinanceGuards(personalWithdrawBlocked: false),
      );
      expect(s.enabled, isTrue);
      expect(s.blockedReason, isNull);
    });

    test('bucket LAIN tetap aktif walau personalWithdrawBlocked true (rem hanya untuk pribadi)', () {
      for (final bucket in ['restock', 'operational', 'scaling', 'emergency']) {
        final s = withdrawButtonState(
          bucket: bucket,
          guards: const FinanceGuards(personalWithdrawBlocked: true),
        );
        expect(s.enabled, isTrue, reason: 'bucket $bucket seharusnya tetap aktif');
      }
    });
  });

  group('monthLabelIndo', () {
    test('YYYY-MM valid → "Agustus 2026"', () {
      expect(monthLabelIndo('2026-08'), 'Agustus 2026');
    });

    test('bulan Januari (indeks pertama) → "Januari 2026"', () {
      expect(monthLabelIndo('2026-01'), 'Januari 2026');
    });

    test('bulan Desember (indeks terakhir) → "Desember 2026"', () {
      expect(monthLabelIndo('2026-12'), 'Desember 2026');
    });

    test('format tak dikenali → string kosong, bukan crash', () {
      expect(monthLabelIndo(''), '');
      expect(monthLabelIndo('2026'), '');
      expect(monthLabelIndo('abcd-ef'), '');
      expect(monthLabelIndo('2026-13'), '');
      expect(monthLabelIndo('2026-00'), '');
    });
  });

  group('basisLabel', () {
    test('basis previous → menyebut "bulan lalu" + nama bulan', () {
      final label = basisLabel(_overview(basis: 'previous', basisMonth: '2026-07'));
      expect(label, contains('bulan lalu'));
      expect(label, contains('Juli 2026'));
    });

    test('basis current_partial → menyebut "bulan berjalan" + diproyeksikan', () {
      final label =
          basisLabel(_overview(basis: 'current_partial', basisMonth: '2026-08'));
      expect(label, contains('bulan berjalan'));
      expect(label, contains('diproyeksikan'));
      expect(label, contains('Agustus 2026'));
    });

    test('basis tak dikenal/kosong → string kosong', () {
      expect(basisLabel(_overview(basis: '', basisMonth: '')), '');
      expect(basisLabel(_overview(basis: 'unknown', basisMonth: '2026-08')), '');
    });
  });

  group('emergencyBarFraction', () {
    test('0 → 0.0', () => expect(emergencyBarFraction(0), 0.0));
    test('negatif → dibatasi 0.0', () => expect(emergencyBarFraction(-10), 0.0));
    test('50 → 0.5', () => expect(emergencyBarFraction(50), 0.5));
    test('100 → 1.0', () => expect(emergencyBarFraction(100), 1.0));
    test('melebihi 100 (target tercapai) → dibatasi 1.0, TIDAK meluber',
        () => expect(emergencyBarFraction(150), 1.0));
  });

  group('missingAllocationSummary & hasMissingAllocations', () {
    test('daftar kosong → string kosong DAN hasMissingAllocations false ("jangan tampilkan apa-apa")', () {
      final o = _overview(missingAllocationDates: const [], missingAllocationCount: 0);
      expect(missingAllocationSummary(o), '');
      expect(hasMissingAllocations(o), isFalse);
    });

    test('count sama dengan panjang list → tanpa keterangan "menampilkan N terbaru"', () {
      final o = _overview(
        missingAllocationDates: const ['2026-08-05', '2026-08-06'],
        missingAllocationCount: 2,
      );
      final s = missingAllocationSummary(o);
      expect(s, contains('2'));
      expect(s, isNot(contains('menampilkan')));
      expect(hasMissingAllocations(o), isTrue);
    });

    test('count LEBIH BESAR dari panjang list (dipotong 60) → sebut keduanya', () {
      final o = _overview(
        missingAllocationDates: const ['2026-08-05'],
        missingAllocationCount: 75,
      );
      final s = missingAllocationSummary(o);
      expect(s, contains('75'));
      expect(s, contains('1'));
      expect(s, contains('menampilkan'));
    });
  });

  group('BackfillSummary', () {
    test('semua allocated:true → pesan tanpa "dilewati"', () {
      final r = BackfillSummary.fromResults(const [
        AllocateResult(allocated: true, revenue: 100000),
        AllocateResult(allocated: true, revenue: 200000),
      ]);
      expect(r.allocatedCount, 2);
      expect(r.skippedCount, 0);
      expect(r.message, isNot(contains('dilewati')));
      expect(r.message, contains('2'));
    });

    test('campuran allocated true/false → sebut keduanya', () {
      final r = BackfillSummary.fromResults(const [
        AllocateResult(allocated: true, revenue: 100000),
        AllocateResult(allocated: false, reason: 'sudah dialokasikan'),
      ]);
      expect(r.allocatedCount, 1);
      expect(r.skippedCount, 1);
      expect(r.message, contains('1'));
      expect(r.message, contains('dilewati'));
    });

    test('semua allocated:false → pesan "semua dilewati", bukan menyiratkan keberhasilan', () {
      final r = BackfillSummary.fromResults(const [
        AllocateResult(allocated: false, reason: 'sudah dialokasikan'),
        AllocateResult(allocated: false, reason: 'sudah dialokasikan'),
      ]);
      expect(r.allocatedCount, 0);
      expect(r.skippedCount, 2);
      expect(r.message, contains('Semua'));
    });

    test('list kosong → pesan "tidak ada tanggal"', () {
      final r = BackfillSummary.fromResults(const []);
      expect(r.message, contains('Tidak ada'));
    });
  });

  group('withdrawErrorMessage', () {
    test('ApiException code DUPLICATE_WITHDRAWAL → pesan proteksi ganda-klik, bukan generik', () {
      final e = ApiException('x', code: 'DUPLICATE_WITHDRAWAL', statusCode: 409);
      final msg = withdrawErrorMessage(e);
      expect(msg, contains('60 detik'));
      expect(msg, isNot(contains('Terjadi kesalahan saat menarik dana')));
    });

    test('ApiException kode lain → pakai pesan aslinya', () {
      final e = ApiException('Saldo tidak cukup', code: 'INSUFFICIENT_BALANCE');
      expect(withdrawErrorMessage(e), 'Saldo tidak cukup');
    });

    test('error non-ApiException → pesan generik', () {
      expect(withdrawErrorMessage(Exception('boom')),
          'Terjadi kesalahan saat menarik dana. Coba lagi.');
    });
  });
}
