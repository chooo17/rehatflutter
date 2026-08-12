import '../../finance/application/finance_ledger_view.dart' show bucketLabel;

/// Logika penyajian & validasi MURNI untuk pemilihan pos (amplop) saat
/// mencatat pengeluaran — terpisah dari widget dialog supaya bisa diuji
/// tanpa merender apa pun.
///
/// **Konteks:** backend kini memotong saldo pos (`finance_ledger`,
/// `direction:'out'`, `source:'expense'`) sesuai `bucket` yang dikirim
/// `POST /admin/expenses`. Sebelum pemilih ini ada, dialog "Catat
/// Pengeluaran" tidak pernah mengirim `bucket` sama sekali, sehingga backend
/// memakai default `'restock'` untuk SEMUA pengeluaran — termasuk yang
/// jelas bukan bahan (mis. "uang makan", "mas irur"). Lihat CLAUDE.md §5g.

/// Pos default saat dialog dibuka — **HARUS** `'restock'` untuk
/// mempertahankan perilaku lama bagi kasir yang menekan Simpan tanpa
/// mengubah apa pun (perilaku sebelum pemilih pos ada).
const String defaultExpenseBucket = 'restock';

/// Lima pos yang bisa dipilih, dalam urutan tampil di dialog. Harus sama
/// persis dengan lima pos amplop alokasi (§5g CLAUDE.md) & CHECK constraint
/// `finance_ledger.bucket` di DB.
const List<String> expenseBucketOptions = [
  'restock',
  'operational',
  'personal',
  'scaling',
  'emergency',
];

/// Label Indonesia untuk satu pos. Re-ekspor peta yang sama dipakai Buku
/// Besar (`finance_ledger_view.dart`) — satu sumber kebenaran untuk label
/// pos di seluruh app, tak digandakan. Kunci tak dikenal ditampilkan apa
/// adanya (fallback aman) alih-alih disembunyikan.
String expenseBucketLabel(String bucket) => bucketLabel(bucket);

/// Apakah [bucket] salah satu dari lima pos yang valid.
bool isValidExpenseBucket(String bucket) => expenseBucketOptions.contains(bucket);

/// Pos yang benar-benar dikirim ke backend untuk request "Catat
/// Pengeluaran". [selected] dipakai bila valid; `null` atau kode tak
/// dikenal jatuh ke [defaultExpenseBucket] — jaring pengaman terakhir
/// supaya dialog tidak pernah mengirim kode pos sembarangan ke backend.
String resolveExpenseBucket(String? selected) =>
    selected != null && isValidExpenseBucket(selected) ? selected : defaultExpenseBucket;
