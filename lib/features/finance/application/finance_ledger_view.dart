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
///
/// Dua jaring pengaman terakhir (ditegakkan DI SINI, satu-satunya titik
/// tempat data masuk ke [LedgerListState], supaya berlaku untuk semua
/// pemanggil):
/// - **`hasMore` tanpa cursor lengkap** dianggap AKHIR DAFTAR
///   (`hasMore` dipaksa `false`, cursor dibuang). Backend hari ini tidak
///   pernah membalas begini, tapi klien tidak boleh bergantung pada itu —
///   memanggil `fetchLedger(before:null, beforeId:null)` akan mengembalikan
///   HALAMAN 1 LAGI, bukan halaman berikutnya, dan itu akan di-append
///   sebagai duplikat berulang setiap tap "Muat lebih banyak".
/// - **Dedupe berdasarkan `id`** — item dari [page] yang `id`-nya sudah ada
///   di [state] TIDAK ditambahkan lagi. Jaring pengaman terakhir bila,
///   akibat sebab lain (balapan filter, retry), halaman yang sama sempat
///   ter-append dua kali.
LedgerListState appendLedgerPage(LedgerListState state, LedgerPage page) {
  final cursorComplete = page.nextBefore != null && page.nextBeforeId != null;
  final hasMore = page.hasMore && cursorComplete;
  final seenIds = state.items.map((e) => e.id).toSet();
  final newItems = page.items.where((e) => seenIds.add(e.id));
  return LedgerListState(
    items: [...state.items, ...newItems],
    hasMore: hasMore,
    nextBefore: hasMore ? page.nextBefore : null,
    nextBeforeId: hasMore ? page.nextBeforeId : null,
  );
}

/// State kosong baru — dipakai saat filter pos berganti. Cursor halaman
/// sebelumnya (dari filter lama) TIDAK boleh dibawa ke filter baru.
LedgerListState resetLedgerState() => LedgerListState.initial;

/// State setelah halaman **PERTAMA** dari [page] tiba untuk filter pos yang
/// SEDANG aktif. Selalu me-reset total (lihat [resetLedgerState]) lalu
/// mengisi dari [page] — TIDAK PERNAH digabung dengan [LedgerListState]
/// sebelumnya (itu milik filter LAMA; cursor-nya tak berlaku untuk filter
/// ini). Fungsi ini sengaja HANYA menerima [page] (tanpa parameter state
/// lama) supaya secara struktural tak mungkin diam-diam berubah jadi
/// APPEND ke state lama — kelas bug yang pernah lolos review sebelumnya.
LedgerListState firstPageState(LedgerPage page) =>
    appendLedgerPage(resetLedgerState(), page);

/// Apakah respons "muat lebih banyak" yang baru tiba — yang dikirim SAAT
/// filter pos aktif adalah [requestedBucket] — sudah BASI dan wajib DIBUANG
/// (bukan di-append ke state).
///
/// Basi kalau filter pos sudah berpindah sejak request dikirim, dicek dari
/// DUA sisi:
/// - [currentFilterBucket]: nilai `ledgerBucketFilterProvider` SAAT respons
///   tiba (mungkin sudah beda dari [requestedBucket] kalau user ganti chip
///   sambil menunggu).
/// - [stateBucket]: filter yang menghasilkan `LedgerListState` yang SEDANG
///   ditampilkan (`_stateBucket` di layar) — bisa sudah diganti oleh
///   halaman PERTAMA filter baru yang datang lebih dulu daripada halaman
///   lanjutan filter lama ini.
///
/// Tanpa pemeriksaan ini, halaman lanjutan dari filter LAMA bisa ter-append
/// ke daftar filter BARU, dan cursor filter BARU ikut tertimpa cursor
/// posisi filter LAMA — baris filter baru bisa terlewat permanen sesudahnya.
bool isLoadMoreResponseStale({
  required String? requestedBucket,
  required String? currentFilterBucket,
  required String? stateBucket,
}) {
  return requestedBucket != currentFilterBucket || requestedBucket != stateBucket;
}

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
