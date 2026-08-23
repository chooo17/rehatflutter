import '../../../core/utils/formatters.dart';
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
