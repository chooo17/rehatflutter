import '../../../core/utils/formatters.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../admin/data/admin_report_repository.dart' show TopItem;
import '../data/stock_repository.dart';

/// Logika penyajian MURNI untuk fitur Manajemen Stok (bahan, resep, HPP) —
/// terpisah dari widget supaya bisa diuji tanpa merender apa pun. Hanya
/// fungsi Dart murni di sini: TANPA import widget Flutter, TANPA
/// `DioClient`/kode jaringan (lihat brief Task 5).

/// Label satuan dasar Bahasa Indonesia untuk kode `base_unit`. `'g'`,
/// `'ml'`, `'pcs'` adalah satu-satunya nilai yang lolos CHECK constraint DB
/// (migrasi 019) — kode lain (data lama/salah) dikembalikan APA ADANYA,
/// bukan string kosong, supaya tidak diam-diam hilang dari tampilan.
String unitLabel(String baseUnit) {
  switch (baseUnit) {
    case 'g':
      return 'gram';
    case 'ml':
      return 'mililiter';
    case 'pcs':
      return 'pcs';
    default:
      return baseUnit;
  }
}

/// Format harga per satuan dasar untuk tampilan, mis. `"Rp 4/gram"`.
/// [costPerBase] boleh pecahan (mis. 3,5) — [Formatters.rupiah] yang
/// membulatkan TAMPILANNYA (`decimalDigits: 0`); fungsi ini TIDAK
/// membulatkan nilainya sendiri sebelum memformat, supaya satu-satunya
/// titik pembulatan tetap di `Formatters.rupiah`.
String formatCostPerUnit(double costPerBase, String baseUnit) =>
    '${Formatters.rupiah(costPerBase)}/${unitLabel(baseUnit)}';

/// Validasi isi per satuan beli (`units_per_purchase`) — backend menolak
/// `<= 0` (CHECK DB migrasi 019 & skema Zod `stock.js`). Mengembalikan
/// pesan Bahasa Indonesia siap tampil, atau `null` bila valid.
String? unitsPerPurchaseError(double value) {
  if (value <= 0) return 'Isi per satuan beli harus lebih dari 0';
  return null;
}

/// Pratinjau harga per satuan dasar **saat mengetik** di form entri bahan
/// (brief Task 6 — "supaya salah konversi 1000× ketahuan saat itu juga,
/// bukan setelah merusak nilai stok"). Dihitung dari input MENTAH form
/// (belum tersimpan), BUKAN dari `Ingredient.costPerBase` — kolom itu
/// hanya ada SETELAH baris tersimpan & dihitung ulang server.
///
/// `null` selama [unitsPerPurchase] belum valid (`<= 0`, termasuk saat
/// kolom masih kosong dan ter-parse ke 0) — supaya form tidak menampilkan
/// pratinjau hasil pembagian-oleh-nol/tak terhingga saat pengguna belum
/// selesai mengetik. Sengaja memakai ambang yang sama dengan
/// [unitsPerPurchaseError], tapi TIDAK memanggilnya — pemanggil (widget)
/// tetap wajib menjalankan [unitsPerPurchaseError] sendiri untuk pesan
/// validasi submit; fungsi ini murni untuk teks pratinjau.
String? livePricePreview({
  required double purchasePrice,
  required double unitsPerPurchase,
  required String baseUnit,
}) {
  if (unitsPerPurchase <= 0) return null;
  return formatCostPerUnit(purchasePrice / unitsPerPurchase, baseUnit);
}

/// Tiga (empat termasuk "sama") keadaan kalimat pembanding HPP resep vs
/// `cost_price` manual lama untuk satu menu (`HppRow`).
enum HppComparisonState {
  /// `hasStored` false — belum ada `cost_price` manual untuk dibandingkan.
  noStoredPrice,

  /// HPP dari resep LEBIH TINGGI dari harga manual lama.
  higher,

  /// HPP dari resep LEBIH RENDAH dari harga manual lama.
  lower,

  /// HPP dari resep SAMA dengan harga manual lama.
  equal,
}

/// Menentukan keadaan pembanding HPP. `hasStored` (BUKAN
/// `storedCostPrice == null`) adalah satu-satunya penentu "ada data
/// pembanding atau tidak" — sesuai kontrak backend (`hppDelta` di
/// `stockCalc.js`: `hasStored = stored > 0`).
HppComparisonState hppComparisonState(HppRow row) {
  if (!row.hasStored) return HppComparisonState.noStoredPrice;
  final delta = row.delta ?? 0;
  if (delta > 0) return HppComparisonState.higher;
  if (delta < 0) return HppComparisonState.lower;
  return HppComparisonState.equal;
}

/// Kalimat siap tampil untuk perbandingan HPP resep vs HPP manual lama,
/// untuk keempat [HppComparisonState].
String hppComparisonSentence(HppRow row) {
  switch (hppComparisonState(row)) {
    case HppComparisonState.noStoredPrice:
      return 'Belum ada HPP manual (cost_price) untuk menu ini — belum bisa dibandingkan.';
    case HppComparisonState.higher:
      return 'HPP dari resep ${Formatters.rupiah(row.delta ?? 0)} lebih tinggi dari HPP manual.';
    case HppComparisonState.lower:
      return 'HPP dari resep ${Formatters.rupiah((row.delta ?? 0).abs())} lebih rendah dari HPP manual.';
    case HppComparisonState.equal:
      return 'HPP dari resep sama dengan HPP manual.';
  }
}

/// ---------------------------------------------------------------------
/// Task 7 — layar entri resep per menu (daftar menu + kalkulator HPP klien)
/// ---------------------------------------------------------------------

/// Satu baris pada daftar menu layar Entri Resep — irisan kecil dari
/// [MenuItemModel] + status resep, SUDAH diurutkan (lihat
/// [sortMenusByPopularity]). Tipe tampilan murni, bukan model jaringan.
class RecipeMenuRow {
  const RecipeMenuRow({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.hasRecipe,
  });

  final String id;
  final String name;

  /// `menu_items.cost_price` apa adanya (0 = belum diisi) — dibawa dari
  /// [MenuItemModel.costPrice], BUKAN dari [HppRow] (list ini dibangun dari
  /// katalog menu lengkap, `HppRow` cuma sumber status resep).
  final int costPrice;

  /// `true` bila menu ini punya minimal satu baris resep ([HppRow.complete]).
  /// `false` untuk menu yang tak muncul sama sekali di [HppRow] (seharusnya
  /// tak terjadi karena endpoint pembanding HPP mencakup semua menu, tapi
  /// diperlakukan aman-secara-default alih-alih exception).
  final bool hasRecipe;
}

/// Urutkan katalog menu untuk layar Entri Resep: menu yang masuk daftar
/// terlaris ([topItems], dari `GET /admin/reports/sales?top_limit=N`)
/// ditaruh di ATAS mengikuti URUTAN yang backend kembalikan (backend sudah
/// mengurutkan berdasar quantity descending — fungsi ini SENGAJA tidak
/// menyortir ulang berdasar angka apa pun, supaya keputusan tie-break/
/// pembulatan tetap satu-satunya milik backend). Sisanya (tak ada di
/// [topItems]) ditaruh setelahnya, diurutkan alfabetis.
///
/// Satu-satunya kunci gabung yang tersedia adalah NAMA PERSIS (`TopItem`
/// tak punya id) — [MenuItemModel.name] dicocokkan case-sensitive terhadap
/// [TopItem.name]. Status "sudah ada resep" diambil dari [hppRows]
/// ([HppRow.complete]), dicocokkan lewat `menuItemId` (bukan nama).
List<RecipeMenuRow> sortMenusByPopularity({
  required List<MenuItemModel> menus,
  required List<TopItem> topItems,
  required List<HppRow> hppRows,
}) {
  final completeById = <String, bool>{
    for (final row in hppRows) row.menuItemId: row.complete,
  };

  // Peringkat = indeks pertama nama ini muncul di topItems (urutan backend
  // dipertahankan apa adanya).
  final popularityRank = <String, int>{};
  for (var i = 0; i < topItems.length; i++) {
    popularityRank.putIfAbsent(topItems[i].name, () => i);
  }

  final rows = menus
      .map((m) => RecipeMenuRow(
            id: m.id,
            name: m.name,
            costPrice: m.costPrice,
            hasRecipe: completeById[m.id] ?? false,
          ))
      .toList();

  rows.sort((a, b) {
    final rankA = popularityRank[a.name];
    final rankB = popularityRank[b.name];
    if (rankA != null && rankB != null) return rankA.compareTo(rankB);
    if (rankA != null) return -1;
    if (rankB != null) return 1;
    return a.name.compareTo(b.name);
  });
  return rows;
}

/// Satu baris resep versi LOKAL — dipakai HANYA untuk kalkulator HPP
/// langsung di form entri resep (sebelum baris tersimpan ke server, jadi
/// belum bisa dihitung ulang oleh backend). Beda dari [RecipeLine]/
/// [RecipeLineInput]: tak punya `id`/`ingredientId` string, cuma
/// tiga field mentah yang dibutuhkan aritmetika.
class LocalRecipeLine {
  const LocalRecipeLine({
    required this.qtyBase,
    required this.costPerBase,
    this.temperature,
  });

  final double qtyBase;
  final double costPerBase;

  /// `'hot'`, `'iced'`, atau `null` (berlaku KEDUA varian) — sama semantik
  /// dengan [RecipeLine.temperature].
  final String? temperature;
}

/// Port MURNI dari `menuHpp` di `stockCalc.js` (backend): jumlah
/// `qtyBase * costPerBase` atas baris yang berlaku untuk [temperature]
/// (baris umum, `temperature == null`, berlaku KEDUA varian; baris
/// bertemperatur hanya masuk hitungan varian yang SAMA), dibulatkan SEKALI
/// di akhir (bukan per baris) ke rupiah terdekat — pembulatan per-baris
/// meleset pada resep dengan banyak baris pecahan kecil (lihat komentar
/// `costPerBase` di `stock_repository.dart` untuk alasan yang sama:
/// jangan bulatkan sebelum semuanya dijumlah).
///
/// [temperature] SELALU persis `'hot'` atau `'iced'` dari UI form sendiri
/// (bukan input HTTP tak tepercaya seperti di backend), jadi fungsi ini
/// TIDAK perlu menangani string suhu tak dikenal secara defensif.
int computeMenuHpp(List<LocalRecipeLine> lines, String temperature) {
  double total = 0;
  for (final line in lines) {
    if (line.temperature == null || line.temperature == temperature) {
      total += line.qtyBase * line.costPerBase;
    }
  }
  return total.round();
}

/// Hasil pembanding HPP terhitung (klien, dari [computeMenuHpp]) vs
/// `cost_price` lama — bentuk sama persis semantiknya dengan `hppDelta` di
/// `stockCalc.js` backend & dengan [HppRow.delta]/[HppRow.pct]/[HppRow.hasStored].
class HppDeltaResult {
  const HppDeltaResult({required this.delta, required this.pct, required this.hasStored});

  /// `null` bila `!hasStored` — SENTINEL DISENGAJA, jangan dikoersi ke 0.
  final int? delta;

  /// `null` bila `!hasStored` — sentinel sama dengan [delta], lihat komentar
  /// `HppRow.pct` di `stock_repository.dart` untuk alasan kelas bug ini
  /// (null vs 0) sudah beberapa kali menggigit modul ini & modul keuangan.
  final double? pct;

  /// `true` hanya bila `storedCostPrice != null && storedCostPrice > 0`.
  final bool hasStored;
}

/// Bandingkan HPP terhitung (klien, real-time saat mengedit) terhadap
/// `cost_price` lama — mirror EKSAK semantik sentinel `hppDelta` backend:
/// `storedCostPrice` yang `null` ATAU `0` (belum pernah diisi) SAMA-SAMA
/// berarti "tak ada data pembanding", bukan "selisihnya 0". Tanpa
/// pembedaan ini, menu yang belum pernah diberi `cost_price` akan tampil
/// seolah HPP resepnya "0% lebih tinggi/rendah" — selisih PALSU untuk data
/// yang sebenarnya tak ada.
HppDeltaResult computeHppDelta({required int computed, required int? storedCostPrice}) {
  final hasStored = storedCostPrice != null && storedCostPrice > 0;
  if (!hasStored) {
    return const HppDeltaResult(delta: null, pct: null, hasStored: false);
  }
  final delta = computed - storedCostPrice;
  final pct = delta / storedCostPrice * 100;
  return HppDeltaResult(delta: delta, pct: pct, hasStored: true);
}
