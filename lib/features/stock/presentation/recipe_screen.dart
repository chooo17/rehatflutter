import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../admin/data/admin_report_repository.dart';
import '../../menu/data/menu_repository.dart';
import '../application/stock_view.dart';
import '../data/stock_repository.dart';

/// Layar Resep (Manajemen Stok Fase A, Task 7) — KHUSUS PEMILIK, sama guard
/// dengan Master Bahan (Task 6) & modul Keuangan (endpoint di belakang
/// `authenticate` + `requireFinanceAccess`).
///
/// Brief awal membaca seolah SATU layar ("daftar menu... entri resep..."),
/// tapi hanya SATU rute yang disebutkan (`stock-recipe`,
/// `/profile/stock/recipe/:menuItemId`) — path itu WAJIB `menuItemId`, yang
/// tak bisa dipakai untuk daftar 58 menu sekaligus. Diselesaikan jadi DUA
/// widget dalam SATU berkas (sesuai daftar file di brief), mengikuti pola
/// `ingredients_screen.dart` yang juga menaruh layar+tile+form dalam satu
/// berkas:
/// - [RecipeListScreen] — rute `stock-recipe-list` (`stock/recipe`, tanpa
///   parameter): daftar menu + status resep, diurutkan paling laris dulu.
/// - [RecipeScreen] — rute `stock-recipe` (`stock/recipe/:menuItemId`,
///   PERSIS seperti brief): form entri resep satu menu, dijangkau dengan
///   menekan baris di [RecipeListScreen].
///
/// BELUM ada tautan navigasi ke [RecipeListScreen] dari layar mana pun
/// (sama seperti Master Bahan Task 6) — dijangkau lewat
/// `context.pushNamed(RouteNames.stockRecipeList)`.

/// Penyedia daftar terlaris untuk pengurutan [RecipeListScreen] —
/// `topLimit: 30` dipilih sebagai cakupan wajar untuk "~21 menu = 80%
/// omzet" (lihat `sortMenusByPopularity` di `stock_view.dart`). `autoDispose`
/// supaya data selalu segar tiap kunjungan, sama pola dengan
/// `analyticsProvider` di `admin_report_repository.dart`.
final stockTopSellingItemsProvider = FutureProvider.autoDispose<List<TopItem>>((ref) async {
  final report =
      await ref.watch(adminReportRepositoryProvider).fetchSales(range: '30d', topLimit: 30);
  return report.topItems;
});

/// -----------------------------------------------------------------------
/// Daftar menu + status resep, diurutkan paling laris dulu.
/// -----------------------------------------------------------------------
class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menusAsync = ref.watch(allMenuItemsProvider);
    final hppAsync = ref.watch(hppComparisonProvider);
    final topAsync = ref.watch(stockTopSellingItemsProvider);

    final menus = menusAsync.valueOrNull;
    final hppRows = hppAsync.valueOrNull;
    final topItems = topAsync.valueOrNull;

    // Keep-previous-data: spinner hanya saat SALAH SATU dari ketiga sumber
    // belum pernah punya data sama sekali — sama pola dengan
    // IngredientsScreen/FinanceOverviewScreen.
    final loading = menus == null || hppRows == null || topItems == null;
    final hasError = menusAsync.hasError || hppAsync.hasError || topAsync.hasError;

    return Scaffold(
      appBar: AppBar(title: const Text('Resep Menu')),
      body: loading
          ? (hasError
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Gagal memuat daftar menu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
          : Builder(builder: (context) {
              final rows = sortMenusByPopularity(
                menus: menus,
                topItems: topItems,
                hppRows: hppRows,
              );
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(allMenuItemsProvider);
                  ref.invalidate(hppComparisonProvider);
                  ref.invalidate(stockTopSellingItemsProvider);
                },
                child: rows.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text('Belum ada menu.', textAlign: TextAlign.center),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: NeuCard(
                              padding: EdgeInsets.zero,
                              // ListTile melukis latar & percikan tinta pada
                              // Material ANCESTOR TERDEKAT — tanpa Material
                              // milik sendiri di sini, ia akan mencoba
                              // "menembus" `DecoratedBox` (latar) milik
                              // NeuCard sampai ke Material Scaffold yang jauh
                              // di atas, dan framework menolaknya (assertion
                              // "background color or ink splashes may be
                              // invisible"). Dibungkus transparan di sini
                              // supaya ListTile punya Material miliknya
                              // sendiri, tepat di dalam NeuCard.
                              child: Material(
                                type: MaterialType.transparency,
                                child: ListTile(
                                  title: Text(row.name),
                                  subtitle: Text(
                                    row.hasRecipe ? 'Resep sudah ada' : 'Belum ada resep',
                                  ),
                                  trailing: Icon(
                                    row.hasRecipe
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color:
                                        row.hasRecipe ? AppColors.success : AppColors.textSecondary,
                                  ),
                                  onTap: () => context.pushNamed(
                                    RouteNames.stockRecipe,
                                    pathParameters: {'menuItemId': row.id},
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              );
            }),
    );
  }
}

/// Baris resep versi form — MUTABLE (beda dari [RecipeLine]/[RecipeLineInput]
/// yang `const`), supaya bisa diedit langsung oleh [_RecipeLineRow] tanpa
/// membangun ulang seluruh daftar tiap ketukan.
class _EditableLine {
  _EditableLine({this.ingredientId, this.qtyBase = 0, this.temperature});

  String? ingredientId;
  double qtyBase;
  String? temperature;
}

/// -----------------------------------------------------------------------
/// Entri resep satu menu: pilih bahan, isi takaran, tandai suhu — HPP
/// terhitung (dua varian) tampil LANGSUNG di bawah saat diedit.
/// -----------------------------------------------------------------------
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key, required this.menuItemId});

  final String menuItemId;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  final List<_EditableLine> _lines = [];
  bool _initialized = false;
  bool _saving = false;
  String? _submitError;

  void _initFromRecipe(MenuRecipe recipe) {
    if (_initialized) return;
    _initialized = true;
    _lines.addAll(recipe.lines.map((l) => _EditableLine(
          ingredientId: l.ingredientId,
          qtyBase: l.qtyBase,
          temperature: l.temperature,
        )));
  }

  void _addLine() => setState(() => _lines.add(_EditableLine()));

  void _removeLine(int index) => setState(() => _lines.removeAt(index));

  Future<void> _save() async {
    setState(() => _submitError = null);
    // Baris tanpa bahan terpilih atau takaran <= 0 diabaikan diam-diam
    // (bukan error) — pengguna boleh menambah baris kosong lalu mengisinya
    // belakangan, atau membiarkannya kosong sebagai draft yang tidak
    // dikirim.
    final validLines = _lines
        .where((l) => (l.ingredientId ?? '').isNotEmpty && l.qtyBase > 0)
        .toList();

    setState(() => _saving = true);
    try {
      await ref.read(stockRepositoryProvider).saveRecipe(
            widget.menuItemId,
            validLines
                .map((l) => RecipeLineInput(
                      ingredientId: l.ingredientId!,
                      qtyBase: l.qtyBase,
                      temperature: l.temperature,
                    ))
                .toList(),
          );
      ref.invalidate(menuRecipeProvider(widget.menuItemId));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Resep tersimpan')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _submitError = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  MenuItemModel? _findMenu(List<MenuItemModel>? menus) {
    if (menus == null) return null;
    for (final m in menus) {
      if (m.id == widget.menuItemId) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(menuRecipeProvider(widget.menuItemId));
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final menusAsync = ref.watch(allMenuItemsProvider);

    final recipe = recipeAsync.valueOrNull;
    final ingredients = ingredientsAsync.valueOrNull ?? const <Ingredient>[];
    final menuItem = _findMenu(menusAsync.valueOrNull);

    if (recipe != null) _initFromRecipe(recipe);

    final ingredientById = {for (final ing in ingredients) ing.id: ing};
    final localLines = _lines
        .map((l) => LocalRecipeLine(
              qtyBase: l.qtyBase,
              costPerBase: ingredientById[l.ingredientId]?.costPerBase ?? 0,
              temperature: l.temperature,
            ))
        .toList();
    final hppHot = computeMenuHpp(localLines, 'hot');
    final hppIced = computeMenuHpp(localLines, 'iced');
    // Dibandingkan terhadap yang TERTINGGI antara dua varian — sama
    // konvensi dengan `hppDelta` backend (lihat komentar `HppRow.delta`
    // di `stock_repository.dart`).
    final delta = computeHppDelta(
      computed: hppHot > hppIced ? hppHot : hppIced,
      storedCostPrice: menuItem?.costPrice,
    );

    final title = (menuItem != null && menuItem.name.isNotEmpty) ? menuItem.name : 'Resep Menu';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // SENGAJA di dalam body (bukan FloatingActionButton) — layar ini juga
      // punya tombol "Simpan Resep" full-width di dasar konten yang bisa
      // sependek satu-dua baris (isi resep sedikit). FAB melayang di posisi
      // TETAP di layar terlepas dari scroll, dan pernah terbukti (widget
      // test) menutupi tombol Simpan sehingga tap-nya tidak pernah sampai
      // ke tombol yang benar.
      body: recipe == null
          ? (recipeAsync.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Gagal memuat resep: ${recipeAsync.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HppSummaryCard(
                    hppHot: hppHot,
                    hppIced: hppIced,
                    storedCostPrice: menuItem?.costPrice,
                    delta: delta,
                  ),
                  const SizedBox(height: 16),
                  Text('Baris Resep', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Belum ada baris resep. Tekan "Tambah Bahan" untuk mulai.',
                      ),
                    ),
                  for (var i = 0; i < _lines.length; i++)
                    _RecipeLineRow(
                      key: ObjectKey(_lines[i]),
                      line: _lines[i],
                      ingredients: ingredients,
                      onChanged: () => setState(() {}),
                      onRemove: () => _removeLine(i),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Bahan'),
                    ),
                  ),
                  if (_submitError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _submitError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: NeuButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan Resep'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

/// Kartu HPP terhitung (dua varian) + selisih dari `cost_price` lama —
/// murni tampilan, semua angka datang dari [computeMenuHpp]/[computeHppDelta]
/// (Task 7, `stock_view.dart`).
class _HppSummaryCard extends StatelessWidget {
  const _HppSummaryCard({
    required this.hppHot,
    required this.hppIced,
    required this.storedCostPrice,
    required this.delta,
  });

  final int hppHot;
  final int hppIced;
  final int? storedCostPrice;
  final HppDeltaResult delta;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HPP Terhitung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Panas: ${Formatters.rupiah(hppHot)}'),
          Text('Dingin: ${Formatters.rupiah(hppIced)}'),
          const SizedBox(height: 8),
          if (!delta.hasStored)
            const Text(
              'Belum ada HPP manual (cost_price) untuk menu ini — belum bisa dibandingkan.',
            )
          else ...[
            Text('HPP manual (cost_price) lama: ${Formatters.rupiah(storedCostPrice ?? 0)}'),
            Text(
              'Selisih: ${Formatters.rupiah(delta.delta ?? 0)} '
              '(${delta.pct?.toStringAsFixed(1)}%)',
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris form resep: pilih bahan, isi takaran, tandai suhu. Menyimpan
/// controller takaran sendiri (`StatefulWidget` terpisah, dikunci lewat
/// `key: ObjectKey(line)` di pemanggil) supaya fokus/kursor tidak hilang
/// saat baris LAIN diedit dan memicu rebuild parent — sama alasan
/// `_IngredientFormSheet` di `ingredients_screen.dart` memakai controller.
class _RecipeLineRow extends StatefulWidget {
  const _RecipeLineRow({
    super.key,
    required this.line,
    required this.ingredients,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableLine line;
  final List<Ingredient> ingredients;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_RecipeLineRow> createState() => _RecipeLineRowState();
}

class _RecipeLineRowState extends State<_RecipeLineRow> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.line.qtyBase > 0 ? _trimZero(widget.line.qtyBase) : '',
    );
    _qtyCtrl.addListener(_onQtyChanged);
  }

  void _onQtyChanged() {
    final t = _qtyCtrl.text.trim().replaceAll(',', '.');
    widget.line.qtyBase = double.tryParse(t) ?? 0;
    widget.onChanged();
  }

  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _qtyCtrl.removeListener(_onQtyChanged);
    _qtyCtrl.dispose();
    super.dispose();
  }

  String? get _selectedBaseUnit {
    final id = widget.line.ingredientId;
    if (id == null) return null;
    for (final ing in widget.ingredients) {
      if (ing.id == id) return ing.baseUnit;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Dropdown Flutter menolak `initialValue`/`value` yang tak ada di
    // daftar `items` (assert di debug) — bahan yang sudah dinonaktifkan
    // sejak resep terakhir disimpan tetap harus muncul sebagai pilihan
    // (bukan hilang diam-diam dari baris yang sudah memakainya).
    final ids = widget.ingredients.map((e) => e.id).toSet();
    final selectedId =
        (widget.line.ingredientId != null && ids.contains(widget.line.ingredientId))
            ? widget.line.ingredientId
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(labelText: 'Bahan'),
                    items: [
                      for (final ing in widget.ingredients)
                        DropdownMenuItem(value: ing.id, child: Text(ing.name)),
                    ],
                    onChanged: (v) {
                      widget.line.ingredientId = v;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus baris',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Takaran',
                hintText: 'dalam satuan dasar bahan',
                suffixText: _selectedBaseUnit == null ? null : unitLabel(_selectedBaseUnit!),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: widget.line.temperature,
              decoration: const InputDecoration(labelText: 'Suhu'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Berlaku keduanya')),
                DropdownMenuItem(value: 'hot', child: Text('Panas')),
                DropdownMenuItem(value: 'iced', child: Text('Dingin')),
              ],
              onChanged: (v) {
                widget.line.temperature = v;
                widget.onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
