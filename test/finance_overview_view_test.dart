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

    test('breakEvenDaily 0 TANPA insufficientData/marginNonPositive → costsUnknown, BUKAN ok/Rp0', () {
      // Skenario nyata: sudah jualan (insufficientData=false), margin positif
      // (marginNonPositive=false), TAPI belum ada satupun baris Biaya Tetap
      // → monthlyCost=0 → breakEvenDaily=0 dari backend. Menampilkan ini
      // sebagai "target Rp0" ("impas tanpa jualan") adalah cacat kritis —
      // harus jadi rambu costsUnknown, bukan status ok.
      final o = _overview(guards: const FinanceGuards(breakEvenDaily: 0));
      final d = breakEvenDisplay(o);
      expect(d.status, BreakEvenStatus.costsUnknown);
    });

    test('breakEvenDaily > 0 → tetap status ok (bukan false positive costsUnknown)', () {
      final o = _overview(guards: const FinanceGuards(breakEvenDaily: 1));
      final d = breakEvenDisplay(o);
      expect(d.status, BreakEvenStatus.ok);
      expect(d.amount, 1);
    });
  });

  group('runwayDisplay', () {
    test('insufficientData true → unknown, walau runwayDays terisi', () {
      final o = _overview(
        insufficientData: true,
        guards: const FinanceGuards(runwayDays: 30),
      );
      expect(runwayDisplay(o).status, RunwayStatus.unknown);
    });

    test('runwayDays negatif → deficit dengan hari APA ADANYA (tidak di-abs)', () {
      final o = _overview(guards: const FinanceGuards(runwayDays: -4, breakEvenDaily: 5000));
      final d = runwayDisplay(o);
      expect(d.status, RunwayStatus.deficit);
      expect(d.days, -4, reason: 'jangan pernah di-abs() — mutasi .abs() harus terdeteksi');
    });

    test('runwayDays 0 & breakEvenDaily 0 (sentinel biaya belum diketahui) → unknown, BUKAN "Cukup 0 hari"', () {
      final o = _overview(guards: const FinanceGuards(runwayDays: 0, breakEvenDaily: 0));
      expect(runwayDisplay(o).status, RunwayStatus.unknown);
    });

    test('runwayDays 0 TAPI breakEvenDaily > 0 (bukan sentinel) → ok dengan 0 hari', () {
      final o = _overview(guards: const FinanceGuards(runwayDays: 0, breakEvenDaily: 5000));
      final d = runwayDisplay(o);
      expect(d.status, RunwayStatus.ok);
      expect(d.days, 0);
    });

    test('runwayDays positif & breakEvenDaily > 0 → ok dengan angka asli', () {
      final o = _overview(guards: const FinanceGuards(runwayDays: 45, breakEvenDaily: 5000));
      final d = runwayDisplay(o);
      expect(d.status, RunwayStatus.ok);
      expect(d.days, 45);
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

  group('bucketIsNegative & bucketDisplayBalance', () {
    test('saldo negatif → bucketIsNegative true', () {
      expect(bucketIsNegative(-500), isTrue);
    });

    test('saldo nol/positif → bucketIsNegative false', () {
      expect(bucketIsNegative(0), isFalse);
      expect(bucketIsNegative(500), isFalse);
    });

    test('bucketDisplayBalance TIDAK PERNAH clamp saldo negatif ke 0', () {
      expect(bucketDisplayBalance(-12345), -12345);
    });

    test('bucketDisplayBalance meneruskan saldo positif apa adanya', () {
      expect(bucketDisplayBalance(12345), 12345);
    });
  });

  group('datesToBackfill', () {
    test('meneruskan missingAllocationDates apa adanya bila tak ada hari ini', () {
      final o = _overview(missingAllocationDates: const ['2026-08-01', '2026-08-05']);
      final result = datesToBackfill(o, now: DateTime.utc(2026, 8, 9, 12));
      expect(result, ['2026-08-01', '2026-08-05']);
    });

    test('hari ini (WIB) TIDAK PERNAH ada dalam daftar yang dikembalikan', () {
      // now = 2026-08-09T20:00 UTC → WIB (+7) = 2026-08-10. Andai backend
      // pernah keliru menyertakan tanggal hari ini, pertahanan kedua ini
      // wajib menyaringnya keluar sebelum dikirim ke `repo.allocate`.
      final o = _overview(
        missingAllocationDates: const ['2026-08-09', '2026-08-10', '2026-08-11'],
      );
      final result = datesToBackfill(o, now: DateTime.utc(2026, 8, 9, 20));
      expect(result, isNot(contains('2026-08-10')));
      expect(result, ['2026-08-09', '2026-08-11']);
    });
  });

  group('missingAllocationSample', () {
    test('daftar kosong → string kosong', () {
      expect(missingAllocationSample(_overview(missingAllocationDates: const [])), '');
    });

    test('satu tanggal → tampilkan tanggal itu saja', () {
      expect(
        missingAllocationSample(_overview(missingAllocationDates: const ['2026-08-05'])),
        '2026-08-05',
      );
    });

    test('lebih dari satu → tampilkan tanggal paling lama & paling baru', () {
      final s = missingAllocationSample(_overview(
        missingAllocationDates: const ['2026-07-01', '2026-07-15', '2026-08-05'],
      ));
      expect(s, contains('2026-07-01'));
      expect(s, contains('2026-08-05'));
    });
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

    test('semua gagal terkirim (failed:true) → dilaporkan sebagai KEGAGALAN, bukan "dilewati"', () {
      // Ini kasus IMPORTANT 1: server 500 / koneksi putus. Pesan TIDAK
      // BOLEH menyiratkan "sudah pernah dialokasikan" — itu penyebab yang
      // salah dan menenangkan padahal pembukuan masih bolong.
      final r = BackfillSummary.fromResults(const [
        AllocateResult(allocated: false, failed: true, reason: 'gagal'),
        AllocateResult(allocated: false, failed: true, reason: 'gagal'),
      ]);
      expect(r.allocatedCount, 0);
      expect(r.skippedCount, 0);
      expect(r.failedCount, 2);
      expect(r.message, contains('gagal'));
      expect(r.message, isNot(contains('sudah pernah dialokasikan')));
    });

    test('campuran berhasil + dilewati + gagal → sebut ketiganya secara terpisah', () {
      final r = BackfillSummary.fromResults(const [
        AllocateResult(allocated: true, revenue: 100000),
        AllocateResult(allocated: false, reason: 'sudah dialokasikan'),
        AllocateResult(allocated: false, failed: true, reason: 'gagal'),
      ]);
      expect(r.allocatedCount, 1);
      expect(r.skippedCount, 1);
      expect(r.failedCount, 1);
      expect(r.message, contains('dilewati'));
      expect(r.message, contains('gagal'));
    });

    test('kegagalan (failed:true) TIDAK PERNAH dihitung sebagai allocated', () {
      final r = BackfillSummary.fromResults(const [
        AllocateResult(allocated: false, failed: true, reason: 'gagal'),
      ]);
      expect(r.allocatedCount, 0,
          reason: 'mutasi "kegagalan dihitung allocated:true" harus terdeteksi di sini');
    });

    test('totalMissingCount > jumlah hasil yang diproses → sisa backlog disebut di pesan', () {
      // IMPORTANT 2: daftar backend dipotong 60. Andai total 75 tapi hanya
      // 60 diproses, sisa 15 tak boleh hilang dari kesadaran pemilik.
      final results = List<AllocateResult>.generate(
          60, (_) => const AllocateResult(allocated: true, revenue: 1000));
      final r = BackfillSummary.fromResults(results, totalMissingCount: 75);
      expect(r.remainingCount, 15);
      expect(r.message, contains('15'));
    });

    test('totalMissingCount sama dengan jumlah hasil → tak ada sisa disebut', () {
      final results = List<AllocateResult>.generate(
          3, (_) => const AllocateResult(allocated: true, revenue: 1000));
      final r = BackfillSummary.fromResults(results, totalMissingCount: 3);
      expect(r.remainingCount, 0);
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
