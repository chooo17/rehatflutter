import '../../../core/network/api_exception.dart';
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
  return BreakEvenDisplay(
    status: BreakEvenStatus.ok,
    amount: overview.guards.breakEvenDaily,
  );
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

/// Hasil menjalankan alokasi untuk sekumpulan tanggal bolong secara
/// berurutan — dipakai widget untuk menyusun pesan ringkasan setelah aksi
/// "Alokasikan semua" selesai.
class BackfillSummary {
  const BackfillSummary({required this.allocatedCount, required this.skippedCount});

  final int allocatedCount;
  final int skippedCount;

  factory BackfillSummary.fromResults(List<AllocateResult> results) {
    final allocated = results.where((r) => r.allocated).length;
    return BackfillSummary(
      allocatedCount: allocated,
      skippedCount: results.length - allocated,
    );
  }

  /// Pesan ringkasan Bahasa Indonesia siap ditampilkan (mis. snackbar).
  String get message {
    if (allocatedCount == 0 && skippedCount == 0) {
      return 'Tidak ada tanggal untuk dialokasikan.';
    }
    if (skippedCount == 0) {
      return '$allocatedCount tanggal berhasil dialokasikan.';
    }
    if (allocatedCount == 0) {
      return 'Semua $skippedCount tanggal dilewati (sudah pernah dialokasikan '
          'atau di luar rentang).';
    }
    return '$allocatedCount tanggal berhasil dialokasikan, $skippedCount dilewati.';
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
