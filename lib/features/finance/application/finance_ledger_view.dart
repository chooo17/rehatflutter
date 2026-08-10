import '../../../core/utils/formatters.dart';
import '../data/finance_repository.dart';

/// Logika penyajian & paginasi MURNI untuk layar Buku Besar (Task 8) —
/// terpisah dari widget supaya bisa diuji tanpa merender apa pun.
///
/// **Kontrak paginasi (lihat `FinanceRepository.fetchLedger` &
/// `finance_repository.dart`):** `GET /admin/finance/ledger` memakai kursor
/// keyset KOMPOSIT (`before` + `before_id`, WAJIB berpasangan). Beberapa
/// baris alokasi harian ditulis dalam SATU insert sehingga `created_at`-nya
/// bisa IDENTIK — kursor untuk halaman berikutnya HARUS diambil apa adanya
/// dari `LedgerPage.nextBefore`/`nextBeforeId` (respons backend), TIDAK
/// PERNAH disusun ulang dari `createdAt` item terakhir di daftar. Menyusun
/// kursor sendiri dari item terakhir akan menghilangkan baris secara
/// permanen dari buku besar setiap kali beberapa baris berbagi timestamp
/// yang sama.

/// State daftar buku besar yang sudah dimuat sejauh ini untuk SATU filter
/// pos. Immutable — setiap perubahan menghasilkan instance baru lewat
/// [appendLedgerPage] atau [resetLedgerState].
class LedgerListState {
  const LedgerListState({
    this.items = const [],
    this.hasMore = false,
    this.nextBefore,
    this.nextBeforeId,
  });

  final List<LedgerEntry> items;
  final bool hasMore;
  final String? nextBefore;
  final String? nextBeforeId;

  /// State kosong — dipakai sebagai titik awal & saat filter pos berganti
  /// (cursor halaman lama tak berlaku untuk filter baru, lihat kontrak di
  /// atas berkas ini).
  static const LedgerListState initial = LedgerListState();
}

/// Menggabungkan [page] ke [state] dengan cara **APPEND** (bukan replace) —
/// item lama tetap ada, item baru ditambahkan di akhir daftar.
///
/// `hasMore`/`nextBefore`/`nextBeforeId` hasil diambil **APA ADANYA** dari
/// [page] (yang berasal langsung dari respons backend
/// `next_before`/`next_before_id`) — BUKAN dihitung ulang dari
/// `state.items` atau `page.items`. Ini titik sambung paling berbahaya di
/// layar ini: menyusun kursor dari item terakhir akan menghilangkan baris
/// yang berbagi `created_at` identik (lihat kontrak di atas berkas ini).
LedgerListState appendLedgerPage(LedgerListState state, LedgerPage page) {
  return LedgerListState(
    items: [...state.items, ...page.items],
    hasMore: page.hasMore,
    nextBefore: page.nextBefore,
    nextBeforeId: page.nextBeforeId,
  );
}

/// State kosong baru — dipakai saat filter pos berganti. Cursor halaman
/// sebelumnya (dari filter lama) TIDAK boleh dibawa ke filter baru.
LedgerListState resetLedgerState() => LedgerListState.initial;

/// Apakah tombol "Muat lebih banyak" boleh ditampilkan/aktif untuk [state].
/// Murni membaca `hasMore` dari backend — TIDAK menyimpulkan dari panjang
/// `items` (daftar bisa kosong untuk filter yang belum pernah ada mutasi,
/// tapi `hasMore` tetap sumber kebenaran tunggal).
bool canLoadMore(LedgerListState state) => state.hasMore;

/// Label pos (bucket) dalam Bahasa Indonesia. Kunci tak dikenal ditampilkan
/// apa adanya (fallback) alih-alih menyembunyikan baris.
const Map<String, String> bucketLabels = {
  'restock': 'Restock',
  'operational': 'Operasional',
  'personal': 'Pribadi',
  'scaling': 'Scaling',
  'emergency': 'Dana Darurat',
};

String bucketLabel(String bucket) => bucketLabels[bucket] ?? bucket;

/// Urutan chip filter pos di layar (tanpa "Semua" — itu direpresentasikan
/// widget sebagai `null` terpisah).
const List<String> bucketFilterKeys = [
  'restock',
  'operational',
  'personal',
  'scaling',
  'emergency',
];

/// Label sumber mutasi dalam Bahasa Indonesia — JANGAN pernah tampilkan
/// kode mentah (`allocation`, `withdrawal`, dst.) langsung ke pengguna.
/// Kunci tak dikenal tetap ditampilkan apa adanya sebagai fallback aman,
/// bukan disembunyikan.
const Map<String, String> sourceLabels = {
  'allocation': 'Alokasi harian',
  'withdrawal': 'Penarikan',
  'expense': 'Pengeluaran',
  'correction': 'Koreksi',
  'shortfall': 'Kekurangan',
};

String sourceLabel(String source) => sourceLabels[source] ?? source;

/// `true` bila [direction] adalah mutasi masuk (`'in'`). Nilai selain
/// `'in'` (termasuk `'out'` maupun data tak dikenal) dianggap keluar —
/// default aman: keraguan ditampilkan sebagai KELUAR (nominal minus),
/// bukan MASUK (nominal plus) yang bisa menyesatkan pemilik soal saldo.
bool isInflow(String direction) => direction == 'in';

String directionLabel(String direction) => isInflow(direction) ? 'Masuk' : 'Keluar';

/// Nominal bertanda untuk satu baris ("+Rp10.000" / "-Rp10.000"). Selalu
/// memakai nilai absolut sebelum diberi tanda — `amount` dari backend bisa
/// datang negatif untuk baris tertentu, tanda tampilan HARUS mengikuti
/// [direction] (sumber kebenaran arah mutasi), bukan sekadar tanda mentah
/// `amount`.
String signedAmountLabel(LedgerEntry entry) {
  final sign = isInflow(entry.direction) ? '+' : '−';
  return '$sign${Formatters.rupiah(entry.amount.abs())}';
}
