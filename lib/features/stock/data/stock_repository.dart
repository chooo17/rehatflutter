import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

/// Manajemen Stok Fase A — bahan (`ingredients`) & resep (`recipes`) per
/// menu, dipakai untuk menghitung HPP dari resep x harga bahan sebagai
/// pembanding `menu_items.cost_price` yang selama ini diisi tangan.
/// Endpoint di balik `authenticate` + `requireFinanceAccess` (khusus
/// pemilik), sama pola dengan `finance_repository.dart` — file ini
/// sengaja meniru gaya file itu (helper `_int`/`_double`/`_bool`,
/// `_unwrap`, model+repository+provider dalam satu berkas).

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _double(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

bool _bool(dynamic v) => v == true;

Map<String, dynamic> _unwrap(dynamic body) => (body is Map && body['data'] is Map)
    ? Map<String, dynamic>.from(body['data'] as Map)
    : Map<String, dynamic>.from(body as Map);

/// Satu bahan baku (raw DB row, SNAKE_CASE — beda dari [RecipeLine] yang
/// camelCase karena datang dari endpoint resep, bukan endpoint bahan).
///
/// `unitsPerPurchase`, `purchasePrice`, `costPerBase`, `minStock` adalah
/// `numeric` di Postgres dan SENGAJA `double` (bukan `int`) — nilainya
/// boleh pecahan (mis. es batu Rp35.000/10kg = Rp3,5/g) dan TIDAK BOLEH
/// dibulatkan saat diparse. Membulatkan `costPerBase` ke rupiah bulat di
/// sini akan meleset ~14% pada resep yang memakai ratusan gram per porsi
/// (lihat `stockCalc.js` di backend — alasan modul ini ada).
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    this.baseUnit = '',
    this.purchaseUnit = '',
    this.unitsPerPurchase = 0,
    this.purchasePrice = 0,
    this.costPerBase = 0,
    this.minStock = 0,
    this.abcClass = '',
    this.isActive = true,
  });

  final String id;
  final String name;

  /// `'g'`, `'ml'`, atau `'pcs'` — satu-satunya nilai yang lolos CHECK
  /// constraint DB (migrasi 019).
  final String baseUnit;

  /// Satuan beli bebas (mis. `'kg'`, `'botol'`, `'dus'`) — TIDAK divalidasi
  /// enum di backend, beda dari [baseUnit].
  final String purchaseUnit;
  final double unitsPerPurchase;

  /// Harga beli TERAKHIR (migrasi 020) — kolom tersimpan, bukan turunan.
  final double purchasePrice;

  /// Harga per satuan dasar, SELALU dihitung SERVER dari
  /// `purchasePrice / unitsPerPurchase`. Pecahan penuh, jangan dibulatkan.
  final double costPerBase;
  final double minStock;

  /// `'A'`, `'B'`, atau `'C'`.
  final String abcClass;
  final bool isActive;

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        baseUnit: (j['base_unit'] ?? '').toString(),
        purchaseUnit: (j['purchase_unit'] ?? '').toString(),
        unitsPerPurchase: _double(j['units_per_purchase']),
        purchasePrice: _double(j['purchase_price']),
        costPerBase: _double(j['cost_per_base']),
        minStock: _double(j['min_stock']),
        abcClass: (j['abc_class'] ?? '').toString(),
        isActive: j['is_active'] == null ? true : j['is_active'] == true,
      );
}

/// Satu baris resep, dari `GET /admin/stock/recipes/:menuItemId` — body
/// endpoint ini CAMELCASE (beda dari [Ingredient] yang snake_case), karena
/// `ingredientName`/`baseUnit`/`costPerBase` adalah hasil JOIN & turunan
/// yang disusun backend, bukan kolom mentah tabel `recipes`.
class RecipeLine {
  const RecipeLine({
    this.id = '',
    required this.ingredientId,
    this.ingredientName = '',
    this.baseUnit = '',
    this.qtyBase = 0,
    this.costPerBase = 0,
    this.temperature,
  });

  /// Id baris `recipes` — kosong untuk baris yang belum pernah disimpan.
  final String id;
  final String ingredientId;
  final String ingredientName;
  final String baseUnit;

  /// Takaran bahan (dalam [baseUnit]) untuk satu porsi — pecahan penuh.
  final double qtyBase;

  /// Harga per satuan dasar bahan ini SAAT resep diambil (untuk tampilan
  /// rincian biaya per baris) — bukan sumber kebenaran HPP total, itu ada
  /// di `MenuRecipe.hppHot`/`hppIced` (dihitung ulang & dibulatkan sekali
  /// oleh backend).
  final double costPerBase;

  /// `'hot'`, `'iced'`, atau `null` — `null` berarti baris ini berlaku
  /// untuk KEDUA varian.
  final String? temperature;

  factory RecipeLine.fromJson(Map<String, dynamic> j) => RecipeLine(
        id: (j['id'] ?? '').toString(),
        ingredientId: (j['ingredientId'] ?? '').toString(),
        ingredientName: (j['ingredientName'] ?? '').toString(),
        baseUnit: (j['baseUnit'] ?? '').toString(),
        qtyBase: _double(j['qtyBase']),
        costPerBase: _double(j['costPerBase']),
        temperature: j['temperature']?.toString(),
      );
}

/// Resep lengkap satu menu + HPP dua varian, dari
/// `GET /admin/stock/recipes/:menuItemId`.
class MenuRecipe {
  const MenuRecipe({
    this.lines = const [],
    this.hppHot = 0,
    this.hppIced = 0,
    this.complete = false,
  });

  final List<RecipeLine> lines;

  /// Rupiah bulat — dibulatkan SEKALI oleh backend, sudah aman ditampilkan
  /// langsung (bukan turunan pecahan yang perlu diformat ulang).
  final int hppHot;
  final int hppIced;

  /// `true` bila menu ini punya minimal satu baris resep. BUKAN "resep
  /// lengkap kedua varian" — menu yang baru punya baris umum
  /// (`temperature: null`) saja sudah `complete: true`, karena baris umum
  /// berlaku untuk kedua varian. Dibaca apa adanya dari backend, JANGAN
  /// disimpulkan ulang dari `lines.isNotEmpty` di sisi klien.
  final bool complete;

  factory MenuRecipe.fromJson(Map<String, dynamic> j) => MenuRecipe(
        lines: ((j['lines'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => RecipeLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        hppHot: _int((j['hpp'] as Map?)?['hot']),
        hppIced: _int((j['hpp'] as Map?)?['iced']),
        complete: _bool(j['complete']),
      );
}

/// Satu baris pembanding HPP terhitung (dari resep) vs `cost_price` lama
/// (diisi tangan), dari `GET /admin/stock/hpp-comparison`.
class HppRow {
  const HppRow({
    required this.menuItemId,
    this.name = '',
    this.storedCostPrice,
    this.computedHot = 0,
    this.computedIced = 0,
    this.delta,
    this.pct,
    this.complete = false,
    this.hasStored = false,
  });

  final String menuItemId;
  final String name;

  /// `menu_items.cost_price` — `null` bila belum pernah diisi manual.
  final int? storedCostPrice;
  final int computedHot;
  final int computedIced;

  /// `computed − stored` (dibandingkan terhadap `MAX(computedHot,computedIced)`
  /// di backend). Positif = HPP resep lebih TINGGI dari harga manual lama.
  final int? delta;

  /// **Sentinel yang DISENGAJA backend, JANGAN dikoersi ke 0.0**: `null`
  /// berarti "belum ada `cost_price` lama untuk dibandingkan" (`hasStored`
  /// false); `0.0` ASLI berarti "pas sama dengan harga lama". Menyamakan
  /// keduanya adalah cacat rambu uang — pola yang sama dengan sentinel
  /// `breakEvenDaily`/`FinanceGuards` di modul keuangan (lihat CLAUDE.md §4).
  final double? pct;

  /// `true` bila menu ini punya minimal satu baris resep.
  final bool complete;

  /// `true` bila `menu_items.cost_price` untuk menu ini > 0. SATU-SATUNYA
  /// penentu keadaan "ada data pembanding" — JANGAN diganti dengan
  /// `storedCostPrice != null` (backend membedakan keduanya secara sengaja
  /// lewat `hppDelta` di `stockCalc.js`).
  final bool hasStored;

  factory HppRow.fromJson(Map<String, dynamic> j) => HppRow(
        menuItemId: (j['menuItemId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        storedCostPrice: j['storedCostPrice'] == null ? null : _int(j['storedCostPrice']),
        computedHot: _int(j['computedHot']),
        computedIced: _int(j['computedIced']),
        delta: j['delta'] == null ? null : _int(j['delta']),
        pct: j['pct'] == null ? null : _double(j['pct']),
        complete: _bool(j['complete']),
        hasStored: _bool(j['hasStored']),
      );
}

/// Satu baris input untuk `PUT /admin/stock/recipes/:menuItemId` — bentuk
/// TERPISAH dari [RecipeLine] karena payload PUT snake_case & hanya butuh
/// tiga field (`ingredient_id`, `qty_base`, `temperature`), sedangkan
/// respons GET ([RecipeLine]) camelCase dan membawa field turunan
/// (`ingredientName`, `baseUnit`, `costPerBase`) yang backend hitung
/// sendiri dan tidak diterima dari klien.
class RecipeLineInput {
  const RecipeLineInput({
    required this.ingredientId,
    required this.qtyBase,
    this.temperature,
  });

  final String ingredientId;
  final double qtyBase;
  final String? temperature;

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'qty_base': qtyBase,
        'temperature': temperature,
      };
}

/// Akses modul stok (khusus pemilik — sama guard dengan
/// `FinanceRepository`: `authenticate` + `requireFinanceAccess`, balas 404
/// untuk akun lain).
class StockRepository {
  StockRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  /// `activeOnly` default backend `true` (hanya bahan aktif) bila tak
  /// dikirim — kirim `false` eksplisit untuk melihat bahan nonaktif juga
  /// (mis. layar arsip).
  Future<List<Ingredient>> fetchIngredients({bool? activeOnly, String? abc}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.stockIngredients,
      query: {
        if (activeOnly != null) 'active_only': activeOnly.toString(),
        if (abc != null && abc.isNotEmpty) 'abc': abc,
      },
    );
    final data = _unwrap(res.data);
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Ingredient.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MenuRecipe> fetchRecipe(String menuItemId) async {
    final res = await _client.get<dynamic>(ApiConstants.stockRecipe(menuItemId));
    return MenuRecipe.fromJson(_unwrap(res.data));
  }

  /// Ganti SELURUH resep menu ini (hapus-lalu-sisip di backend, bukan
  /// menambah baris ke resep lama). Respons PUT backend adalah baris DB
  /// mentah (snake_case, TANPA `ingredientName`/`hpp`) — bentuk yang beda
  /// dari [fetchRecipe], jadi method ini sengaja `void`; pemanggil (Task
  /// 6-8) wajib memanggil ulang [fetchRecipe] (lewat [menuRecipeProvider])
  /// untuk mendapat HPP terbaru, bukan mengurai respons PUT ini.
  Future<void> saveRecipe(String menuItemId, List<RecipeLineInput> lines) async {
    await _client.put<dynamic>(
      ApiConstants.stockRecipe(menuItemId),
      data: {'lines': lines.map((l) => l.toJson()).toList()},
    );
  }

  Future<List<HppRow>> fetchHppComparison() async {
    final res = await _client.get<dynamic>(ApiConstants.stockHppComparison);
    final data = _unwrap(res.data);
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HppRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Buat bahan baru (Task 6 — layar Master Bahan). Backend membalas 201
  /// dengan baris lengkap, bentuk SAMA dengan item [fetchIngredients] —
  /// diuraikan langsung ke [Ingredient], beda dari [saveRecipe] yang
  /// sengaja `void` karena bentuk responsnya berbeda dari [fetchRecipe].
  ///
  /// Error 400 (validasi field), 409 `INGREDIENT_DUPLICATE_NAME`, dan 409
  /// `INGREDIENT_INACTIVE_EXISTS` (bahan nonaktif bernama sama sudah ada —
  /// pesannya mengarahkan pemanggil memakai [updateIngredient] dengan
  /// `isActive: true` alih-alih membuat baris baru) dilempar sebagai
  /// [ApiException] apa adanya — `message`-nya sudah Bahasa Indonesia dan
  /// siap ditampilkan ke pengguna, sama pola dengan
  /// `FinanceRepository.withdraw`.
  Future<Ingredient> createIngredient({
    required String name,
    required String baseUnit,
    required String purchaseUnit,
    required double unitsPerPurchase,
    required double purchasePrice,
    double? minStock,
    String? abcClass,
  }) async {
    final res = await _client.post<dynamic>(ApiConstants.stockIngredients, data: {
      'name': name.trim(),
      'base_unit': baseUnit,
      'purchase_unit': purchaseUnit.trim(),
      'units_per_purchase': unitsPerPurchase,
      'purchase_price': purchasePrice,
      if (minStock != null) 'min_stock': minStock,
      if (abcClass != null && abcClass.isNotEmpty) 'abc_class': abcClass,
    });
    return Ingredient.fromJson(_unwrap(res.data));
  }

  /// Perbarui bahan (partial update — hanya field yang diisi yang dikirim).
  /// Backend membalas 400 `EMPTY_PATCH` bila tak ada field sama sekali
  /// (jangan panggil tanpa mengisi minimal satu parameter selain [id]).
  /// Kirim `isActive: true` untuk mengaktifkan kembali bahan yang
  /// dinonaktifkan — lihat catatan `INGREDIENT_INACTIVE_EXISTS` di
  /// [createIngredient].
  Future<Ingredient> updateIngredient(
    String id, {
    String? name,
    String? baseUnit,
    String? purchaseUnit,
    double? unitsPerPurchase,
    double? purchasePrice,
    double? minStock,
    String? abcClass,
    bool? isActive,
  }) async {
    final res = await _client.patch<dynamic>(ApiConstants.stockIngredient(id), data: {
      if (name != null) 'name': name.trim(),
      if (baseUnit != null) 'base_unit': baseUnit,
      if (purchaseUnit != null) 'purchase_unit': purchaseUnit.trim(),
      if (unitsPerPurchase != null) 'units_per_purchase': unitsPerPurchase,
      if (purchasePrice != null) 'purchase_price': purchasePrice,
      if (minStock != null) 'min_stock': minStock,
      if (abcClass != null) 'abc_class': abcClass,
      if (isActive != null) 'is_active': isActive,
    });
    return Ingredient.fromJson(_unwrap(res.data));
  }

  /// Nonaktifkan bahan (`is_active=false`) — backend TIDAK menghapus baris
  /// (lihat dokumentasi kontrak di brief Task 6). `void` sama pola dengan
  /// `FinanceRepository.deleteFixedCost`; pemanggil wajib meng-invalidate
  /// [ingredientsProvider] sendiri setelah sukses.
  Future<void> deactivateIngredient(String id) async {
    await _client.delete<dynamic>(ApiConstants.stockIngredient(id));
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(client: ref.watch(dioClientProvider));
});

/// **`autoDispose`** — sama alasan dengan `financeOverviewProvider` /
/// `ledgerProvider` di `finance_repository.dart` (lihat komentar di sana
/// untuk cerita lengkap): tanpa ini, kunjungan KEDUA ke layar Master Bahan
/// (pop lalu push lagi lewat router) menemukan provider ini SUDAH
/// `AsyncData` dari kunjungan sebelumnya, sehingga daftar bahan yang baru
/// saja dibuat/diubah/dinonaktifkan di kunjungan pertama tidak pernah
/// muncul di kunjungan kedua tanpa pull-to-refresh manual. `autoDispose`
/// membuang provider begitu layar tak lagi punya listener, sehingga
/// kunjungan berikutnya SELALU memicu fetch baru.
final ingredientsProvider = FutureProvider.autoDispose<List<Ingredient>>((ref) {
  return ref.watch(stockRepositoryProvider).fetchIngredients();
});

/// **`autoDispose`** — Task 5 punya provider ini sebagai `FutureProvider.family`
/// polos & reviewnya menandai ini sebagai risiko ke depan (staleness bug yang
/// sama sudah dua kali menggigit modul keuangan; Task 6 sudah mengonversi
/// [ingredientsProvider]). Task 7 (layar entri resep) memakai provider ini
/// dan menyimpan resep lewat [StockRepository.saveRecipe] — tanpa
/// `autoDispose`, kunjungan KEDUA ke layar entri resep menu yang sama
/// (pop lalu push lagi) akan menemukan `AsyncData` basi dari kunjungan
/// pertama, bukan resep yang baru saja disimpan. Pemanggil `saveRecipe`
/// WAJIB `ref.invalidate(menuRecipeProvider(menuItemId))` setelah sukses.
final menuRecipeProvider =
    FutureProvider.family.autoDispose<MenuRecipe, String>((ref, menuItemId) {
  return ref.watch(stockRepositoryProvider).fetchRecipe(menuItemId);
});

final hppComparisonProvider = FutureProvider<List<HppRow>>((ref) {
  return ref.watch(stockRepositoryProvider).fetchHppComparison();
});
