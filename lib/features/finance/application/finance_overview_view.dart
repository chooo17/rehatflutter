import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../data/finance_repository.dart';

/// Logika penyajian murni untuk layar Ringkasan Keuangan (Task 7).
///
/// Sengaja dipisah dari widget supaya bisa diuji tanpa merender apa pun —
/// keputusan "kapan tampilkan angka vs peringatan" di sini adalah rambu
/// UANG (§3 brief Task 7): salah menampilkan Rp0 sebagai kabar baik adalah
/// cacat paling serius yang bisa terjadi di layar ini.

/// Status tampilan rambu break-even harian.
enum BreakEvenStatus {
  /// Belum ada omzet sama sekali — jangan tampilkan angka apa pun.
  insufficientData,

  /// Ada omzet tapi margin ≤ 0 (jual rugi) — target Rp0 akan MENYESATKAN.
  marginNonPositive,

  /// Ada omzet & margin positif TAPI `breakEvenDaily == 0` — sentinel
  /// backend untuk "biaya bulanan belum diketahui" (mis. Biaya Tetap masih
  /// kosong), BUKAN "impas tanpa jualan". Rp0 di sini akan MENYESATKAN
  /// persis seperti dua kondisi di atas.
  costsUnknown,

  /// Angka [BreakEvenDisplay.amount] valid untuk ditampilkan.
  ok,
}

class BreakEvenDisplay {
  const BreakEvenDisplay({required this.status, this.amount = 0});

  final BreakEvenStatus status;
  final int amount;
}

/// Menentukan apa yang boleh ditampilkan untuk break-even harian.
/// `insufficientData` diperiksa LEBIH DULU dari `marginNonPositive` karena
/// tanpa omzet sama sekali margin pun tak bermakna dihitung.
BreakEvenDisplay breakEvenDisplay(FinanceOverview overview) {
  if (overview.insufficientData) {
    return const BreakEvenDisplay(status: BreakEvenStatus.insufficientData);
  }
  if (overview.marginNonPositive) {
    return const BreakEvenDisplay(status: BreakEvenStatus.marginNonPositive);
  }
  // `breakEvenDaily == 0` di sini bukan target yang tercapai — itu sentinel
  // backend untuk "biaya bulanan (fixedCosts + variabel) belum diketahui",
  // biasanya karena layar Biaya Tetap masih kosong. Menampilkannya sebagai
  // Rp0 sama menyesatkannya dengan dua kondisi di atas.
  if (overview.guards.breakEvenDaily == 0) {
    return const BreakEvenDisplay(status: BreakEvenStatus.costsUnknown);
  }
  return BreakEvenDisplay(
    status: BreakEvenStatus.ok,
    amount: overview.guards.breakEvenDaily,
  );
}

/// Status tampilan rambu runway operasional.
enum RunwayStatus {
  /// Belum bisa dihitung — data belum cukup ATAU biaya bulanan belum
  /// diketahui (sentinel `runwayDays == 0` yang berdampingan dengan
  /// `breakEvenDaily == 0`, lihat [breakEvenDisplay]). BUKAN "kas habis".
  unknown,

  /// Runway negatif nyata dari backend — pos operasional SUDAH minus.
  /// Kalimat tampilan harus mencerminkan defisit, bukan "cukup N hari".
  deficit,

  /// [RunwayDisplay.days] valid untuk ditampilkan sebagai "Cukup N hari".
  ok,
}

class RunwayDisplay {
  const RunwayDisplay({required this.status, this.days = 0});

  final RunwayStatus status;

  /// Hari APA ADANYA dari backend — TIDAK di-`abs()`. Untuk [deficit] ini
  /// tetap negatif (mis. -4) supaya pemanggil bisa menyusun kalimat yang
  /// jujur soal defisitnya, bukan angka positif yang menyamarkannya.
  final int days;
}

/// Menentukan apa yang boleh ditampilkan untuk runway operasional.
/// Urutan pemeriksaan penting: `insufficientData` lebih dulu, lalu nilai
/// NEGATIF nyata (defisit sungguhan, harus tetap dilaporkan sebagai
/// defisit meski `breakEvenDaily` kebetulan juga 0), baru sentinel
/// "0 & 0" (biaya belum diketahui).
RunwayDisplay runwayDisplay(FinanceOverview overview) {
  if (overview.insufficientData) {
    return const RunwayDisplay(status: RunwayStatus.unknown);
  }
  final days = overview.guards.runwayDays;
  if (days < 0) {
    return RunwayDisplay(status: RunwayStatus.deficit, days: days);
  }
  if (days == 0 && overview.guards.breakEvenDaily == 0) {
    return const RunwayDisplay(status: RunwayStatus.unknown);
  }
  return RunwayDisplay(status: RunwayStatus.ok, days: days);
}

/// Peringatan tambahan untuk runway ketika biaya variabel tidak lengkap di
/// backend — `null` bila tidak perlu peringatan.
String? runwayWarning(FinanceOverview overview) {
  if (!overview.variableExpensesUnavailable) return null;
  return 'Biaya belum lengkap — runway di atas kemungkinan terlalu panjang '
      'dan rem tarik-pribadi bisa meleset.';
}

/// Keadaan tombol tarik untuk satu amplop.
class WithdrawButtonState {
  const WithdrawButtonState({required this.enabled, this.blockedReason});

  final bool enabled;

  /// Terisi HANYA bila [enabled] false — alasan yang bisa dibaca pemilik.
  final String? blockedReason;
}

/// Nama bucket yang direm khusus (Pribadi) — bucket lain selalu bisa ditarik
/// dari layar ini terlepas dari `personalWithdrawBlocked`.
const String personalBucketKey = 'personal';

/// Status tombol tarik untuk bucket [bucket]. Hanya bucket Pribadi yang bisa
/// terkunci oleh rambu `personalWithdrawBlocked` — restock/operasional/
/// scaling/darurat selalu bisa ditarik dari layar ini.
WithdrawButtonState withdrawButtonState({
  required String bucket,
  required FinanceGuards guards,
}) {
  if (bucket == personalBucketKey && guards.personalWithdrawBlocked) {
    return const WithdrawButtonState(
      enabled: false,
      blockedReason:
          'Saldo operasional belum menutup biaya bulanan — tarik pribadi '
          'dikunci sampai amplop operasional pulih.',
    );
  }
  return const WithdrawButtonState(enabled: true);
}

/// Apakah saldo bucket dianggap defisit (pewarnaan & keterangan "Defisit").
/// Diekstrak jadi fungsi murni terpisah supaya bisa diuji tanpa merender
/// widget — mutasi `balance < 0` → `false` akan langsung ketahuan.
bool bucketIsNegative(int balance) => balance < 0;

/// Nilai saldo yang DITAMPILKAN di kartu amplop. Sengaja identitas (bukan
/// `balance < 0 ? 0 : balance`) — saldo negatif adalah bukti overspend
/// nyata dan TIDAK PERNAH boleh di-clamp ke 0 di layar ini.
int bucketDisplayBalance(int balance) => balance;

/// Nama bulan Indonesia — dipakai lokal di sini (bukan lewat `intl`
/// `DateFormat`) supaya fungsi ini murni & tidak butuh inisialisasi locale
/// data saat diuji.
const List<String> _bulanIndo = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Mengubah `YYYY-MM` menjadi "Agustus 2026". Mengembalikan string kosong
/// bila format tak dikenali (mis. data belum ada) — pemanggil menyembunyikan
/// baris dasar perhitungan bila kosong, bukan menampilkan "null 2026".
String monthLabelIndo(String yyyyMm) {
  final parts = yyyyMm.split('-');
  if (parts.length != 2) return '';
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[0]);
  if (month == null || year == null || month < 1 || month > 12) return '';
  return '${_bulanIndo[month - 1]} $year';
}

/// Label dasar perhitungan rambu ("Berdasarkan bulan lalu: Juli 2026" dst.)
/// supaya pemilik tahu dari bulan mana angka break-even/runway berasal.
/// String kosong bila [FinanceOverview.basis] tak dikenal (belum ada data).
String basisLabel(FinanceOverview overview) {
  final month = monthLabelIndo(overview.basisMonth);
  switch (overview.basis) {
    case 'previous':
      return month.isEmpty
          ? 'Berdasarkan bulan lalu (penuh).'
          : 'Berdasarkan bulan lalu ($month, penuh).';
    case 'current_partial':
      return month.isEmpty
          ? 'Berdasarkan bulan berjalan (diproyeksikan, belum lengkap).'
          : 'Berdasarkan bulan berjalan ($month, diproyeksikan, belum lengkap).';
    default:
      return '';
  }
}

/// Pecahan (0.0–1.0) untuk lebar bar progres dana darurat. `emergencyPct`
/// bisa melebihi 100 (target sudah tercapai/terlampaui) — bar tetap dibatasi
/// penuh, TAPI teks persentase yang ditampilkan di widget harus tetap
/// memakai `emergencyPct` mentah, bukan hasil fungsi ini.
double emergencyBarFraction(int emergencyPct) {
  if (emergencyPct <= 0) return 0.0;
  if (emergencyPct >= 100) return 1.0;
  return emergencyPct / 100;
}

/// Ringkasan teks untuk tanggal-tanggal yang belum dialokasikan. String
/// kosong ("tidak tampil apa-apa") bila daftar kosong — sesuai instruksi:
/// "bila daftar kosong, jangan tampilkan apa-apa".
String missingAllocationSummary(FinanceOverview overview) {
  final dates = overview.missingAllocationDates;
  if (dates.isEmpty) return '';
  final total = overview.missingAllocationCount;
  final shown = dates.length;
  if (total > shown) {
    return '$total tanggal belum dialokasikan (menampilkan $shown terbaru).';
  }
  final noun = total == 1 ? 'tanggal' : 'tanggal';
  return '$total $noun belum dialokasikan.';
}

/// Apakah kartu/aksi "alokasikan tanggal bolong" perlu ditampilkan sama
/// sekali.
bool hasMissingAllocations(FinanceOverview overview) =>
    overview.missingAllocationDates.isNotEmpty;

/// Beberapa contoh tanggal dari backlog supaya pemilik bisa cross-check —
/// bukan cuma melihat sebuah angka. `missingAllocationDates` sudah terurut
/// menaik dari backend, jadi elemen pertama = paling lama, elemen terakhir
/// = paling baru. String kosong bila daftar kosong.
String missingAllocationSample(FinanceOverview overview) {
  final dates = overview.missingAllocationDates;
  if (dates.isEmpty) return '';
  if (dates.length == 1) return dates.first;
  return '${dates.first} s/d ${dates.last}';
}

/// Kunci tanggal WIB hari ini dalam format `YYYY-MM-DD` — dipakai sebagai
/// pertahanan kedua di [datesToBackfill].
String _wibDateKey(DateTime now) {
  final wib = Formatters.toWib(now);
  final y = wib.year.toString().padLeft(4, '0');
  final m = wib.month.toString().padLeft(2, '0');
  final d = wib.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Tanggal yang akan diproses aksi "Alokasikan tanggal bolong". Pada
/// dasarnya salinan `missingAllocationDates` dari backend APA ADANYA, TAPI
/// hari ini (WIB) disaring keluar secara eksplisit sebagai lapis
/// pertahanan kedua — mengirim tanggal hari ini akan mengunci alokasi pada
/// omzet yang belum selesai/parsial dan tak bisa dikoreksi lagi setelahnya.
/// [now] hanya untuk keperluan test (default `DateTime.now()`).
List<String> datesToBackfill(FinanceOverview overview, {DateTime? now}) {
  final todayKey = _wibDateKey(now ?? DateTime.now());
  return overview.missingAllocationDates.where((d) => d != todayKey).toList();
}

/// Hasil menjalankan alokasi untuk sekumpulan tanggal bolong secara
/// berurutan — dipakai widget untuk menyusun pesan ringkasan setelah aksi
/// "Alokasikan semua" selesai.
class BackfillSummary {
  const BackfillSummary({
    required this.allocatedCount,
    required this.skippedCount,
    this.failedCount = 0,
    this.remainingCount = 0,
  });

  final int allocatedCount;

  /// Backend membalas 200 tapi `allocated:false` (mis. sudah pernah
  /// dialokasikan / di luar rentang) — BUKAN kegagalan.
  final int skippedCount;

  /// Permintaan gagal total (jaringan/server, exception dilempar) — HARUS
  /// dilaporkan sebagai kegagalan, bukan disamakan dengan "dilewati" yang
  /// menenangkan padahal pembukuan masih bolong.
  final int failedCount;

  /// Sisa backlog yang tak sempat diproses karena daftar dipotong 60 oleh
  /// backend (`missingAllocationCount` bisa lebih besar dari jumlah
  /// tanggal yang dikirim ke [fromResults]).
  final int remainingCount;

  /// [totalMissingCount] = `overview.missingAllocationCount` SEBELUM aksi
  /// dijalankan — dipakai untuk menghitung [remainingCount] (tanggal yang
  /// tak pernah dicoba karena daftar backend dipotong 60).
  factory BackfillSummary.fromResults(
    List<AllocateResult> results, {
    int totalMissingCount = 0,
  }) {
    final allocated = results.where((r) => r.allocated).length;
    final failed = results.where((r) => !r.allocated && r.failed).length;
    final skipped = results.length - allocated - failed;
    final remaining = totalMissingCount - results.length;
    return BackfillSummary(
      allocatedCount: allocated,
      skippedCount: skipped,
      failedCount: failed,
      remainingCount: remaining > 0 ? remaining : 0,
    );
  }

  /// Pesan ringkasan Bahasa Indonesia siap ditampilkan (mis. snackbar).
  String get message {
    if (allocatedCount == 0 && skippedCount == 0 && failedCount == 0) {
      return 'Tidak ada tanggal untuk dialokasikan.';
    }
    String core;
    if (skippedCount == 0 && failedCount == 0) {
      core = '$allocatedCount tanggal berhasil dialokasikan.';
    } else if (allocatedCount == 0 && failedCount == 0) {
      core = 'Semua $skippedCount tanggal dilewati (sudah pernah dialokasikan '
          'atau di luar rentang).';
    } else if (allocatedCount == 0 && skippedCount == 0) {
      core = 'Semua $failedCount tanggal gagal dialokasikan (masalah '
          'jaringan/server) — pembukuan masih bolong, coba lagi.';
    } else {
      final parts = <String>['$allocatedCount berhasil'];
      if (skippedCount > 0) parts.add('$skippedCount dilewati');
      if (failedCount > 0) {
        parts.add('$failedCount gagal (jaringan/server)');
      }
      core = '${parts.join(', ')}.';
    }
    if (remainingCount > 0) {
      core += ' Masih ada $remainingCount tanggal lain yang belum diproses '
          '(di luar 60 yang ditampilkan).';
    }
    return core;
  }
}

/// Menerjemahkan galat penarikan menjadi pesan yang bisa dipahami pemilik.
/// `DUPLICATE_WITHDRAWAL` (409, penarikan identik dalam 60 detik) BUKAN
/// "terjadi kesalahan" generik — pemilik perlu tahu itu proteksi ganda-klik,
/// bukan kegagalan sistem.
String withdrawErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.code == 'DUPLICATE_WITHDRAWAL') {
      return 'Penarikan yang sama baru saja dilakukan (dalam 60 detik '
          'terakhir). Tunggu sebentar sebelum mencoba lagi — ini proteksi '
          'anti-klik-ganda, bukan kegagalan sistem.';
    }
    return error.message;
  }
  return 'Terjadi kesalahan saat menarik dana. Coba lagi.';
}
