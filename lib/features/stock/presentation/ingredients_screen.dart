import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/neu.dart';
import '../application/stock_view.dart';
import '../data/stock_repository.dart';

/// Layar Master Bahan (Manajemen Stok Fase A, Task 6) — KHUSUS PEMILIK
/// (endpoint di belakang `authenticate` + `requireFinanceAccess`, sama guard
/// dengan modul Keuangan — lihat `StockRepository`). Daftar bahan + form
/// tambah/ubah bertingkat (bottom sheet), mengikuti pola
/// `FixedCostsScreen`/`_AddFixedCostSheet` di modul Keuangan.
///
/// Dijangkau lewat `context.pushNamed('stock-ingredients')` — **belum ada
/// tautan navigasi** dari layar mana pun (itu cakupan Task 8), jadi rute ini
/// sengaja "tersembunyi" untuk saat ini sesuai brief Task 6.
class IngredientsScreen extends ConsumerWidget {
  const IngredientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingredientsProvider);
    final items = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Master Bahan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      // Keep-previous-data: spinner hanya saat benar-benar belum ada data
      // (pola sama dengan FixedCostsScreen/FinanceOverviewScreen).
      body: items == null
          ? (async.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Gagal memuat daftar bahan: ${async.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(ingredientsProvider),
              child: items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Belum ada bahan.\nTambahkan bahan sesuai cara Anda '
                            'benar-benar membeli (mis. Kopi Arabika, satuan beli '
                            'kg, isi 1000 gram per kg).',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Layar lebar: bahan jadi grid (tile membawa jarak
                        // bawah 12 sendiri → runSpacing 0).
                        ResponsiveGrid(
                          minItemWidth: 340,
                          maxColumns: 3,
                          runSpacing: 0,
                          children: [
                            for (final ing in items)
                              _IngredientTile(
                                ingredient: ing,
                                onEdit: () => _showFormSheet(context, ref, editing: ing),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
    );
  }

  void _showFormSheet(BuildContext context, WidgetRef ref, {Ingredient? editing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IngredientFormSheet(ref: ref, editing: editing),
    );
  }
}

class _IngredientTile extends ConsumerWidget {
  const _IngredientTile({required this.ingredient, required this.onEdit});

  final Ingredient ingredient;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = <String>[
      ingredient.purchaseUnit.isEmpty ? '-' : ingredient.purchaseUnit,
      formatCostPerUnit(ingredient.costPerBase, ingredient.baseUnit),
      'Golongan ${ingredient.abcClass.isEmpty ? '-' : ingredient.abcClass}',
      if (!ingredient.isActive) 'nonaktif',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        padding: EdgeInsets.zero,
        // ListTile melukis latar & percikan tinta pada Material ANCESTOR
        // TERDEKAT — NeuCard sendiri tidak menyediakan satu (parameter
        // `onTap` miliknya tidak dipakai di sini, hanya `ListTile.onTap`),
        // jadi tanpa Material transparan ini efek tap ListTile tak pernah
        // terlihat. Sama pola persis dengan `RecipeListScreen` di
        // `recipe_screen.dart` (Task 7).
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            onTap: onEdit,
            title: Text(ingredient.name),
            subtitle: Text(subtitleParts.join(' · ')),
            trailing: IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Nonaktifkan',
              onPressed: () => _confirmDeactivate(context, ref, ingredient),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref, Ingredient ing) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan bahan?'),
        content: Text(
          '${ing.name} akan ditandai nonaktif (baris TIDAK dihapus — bisa '
          'diaktifkan kembali nanti).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(stockRepositoryProvider).deactivateIngredient(ing.id);
      ref.invalidate(ingredientsProvider);
      // HppComparisonScreen (layar hub) bisa tetap ter-mount di bawah lewat
      // "Kelola Bahan" — tanpa ini badge/HPP di sana tetap basi sampai
      // pull-to-refresh manual walau bahan baru saja dinonaktifkan (temuan
      // I-1, review whole-branch feat/stok-fase-a; sama pola dengan
      // RecipeScreen._save()).
      ref.invalidate(hppComparisonProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

/// Form tambah/ubah bahan — `StatefulWidget` terpisah supaya controller
/// punya lifecycle jelas dan dibuang lewat `dispose()`, sama pola dengan
/// `_AddFixedCostSheet` di `fixed_costs_screen.dart`.
class _IngredientFormSheet extends StatefulWidget {
  const _IngredientFormSheet({required this.ref, this.editing});

  final WidgetRef ref;

  /// `null` = mode tambah baru. Terisi = mode ubah, form diisi awal dari
  /// baris ini.
  final Ingredient? editing;

  @override
  State<_IngredientFormSheet> createState() => _IngredientFormSheetState();
}

class _IngredientFormSheetState extends State<_IngredientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _purchaseUnitCtrl;
  late final TextEditingController _unitsPerPurchaseCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _minStockCtrl;
  String? _baseUnit;
  String _abcClass = 'C';
  bool _saving = false;
  String? _submitError;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _purchaseUnitCtrl = TextEditingController(text: e?.purchaseUnit ?? '');
    _unitsPerPurchaseCtrl = TextEditingController(
      text: (e != null && e.unitsPerPurchase > 0) ? _trimZero(e.unitsPerPurchase) : '',
    );
    _purchasePriceCtrl = TextEditingController(
      text: (e != null && e.purchasePrice > 0) ? _trimZero(e.purchasePrice) : '',
    );
    _minStockCtrl = TextEditingController(
      text: (e != null && e.minStock > 0) ? _trimZero(e.minStock) : '',
    );
    _baseUnit = (e != null && e.baseUnit.isNotEmpty) ? e.baseUnit : null;
    _abcClass = (e != null && e.abcClass.isNotEmpty) ? e.abcClass : 'C';

    // Pratinjau harga per satuan dasar wajib mengikuti KETIKAN, bukan hanya
    // submit — pasang listener supaya setiap perubahan di kedua field ini
    // memicu rebuild (brief Task 6: "supaya salah konversi 1000x ketahuan
    // saat itu juga").
    _unitsPerPurchaseCtrl.addListener(_onPreviewInputChanged);
    _purchasePriceCtrl.addListener(_onPreviewInputChanged);
  }

  void _onPreviewInputChanged() => setState(() {});

  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _unitsPerPurchaseCtrl.removeListener(_onPreviewInputChanged);
    _purchasePriceCtrl.removeListener(_onPreviewInputChanged);
    _nameCtrl.dispose();
    _purchaseUnitCtrl.dispose();
    _unitsPerPurchaseCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  double? _parseNum(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Pratinjau harga per satuan dasar dari input MENTAH form saat ini —
  /// bungkus tipis di atas `livePricePreview` (murni, teruji di
  /// `stock_view_test.dart`), TIDAK menduplikasi ambang validasinya.
  String? get _preview {
    final baseUnit = _baseUnit;
    if (baseUnit == null) return null;
    return livePricePreview(
      purchasePrice: _parseNum(_purchasePriceCtrl.text) ?? 0,
      unitsPerPurchase: _parseNum(_unitsPerPurchaseCtrl.text) ?? 0,
      baseUnit: baseUnit,
    );
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    // Form kosong ditolak: validator per-field (di bawah) menolak nama,
    // satuan beli, isi per satuan beli, dan harga yang kosong.
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;
    if (_baseUnit == null) {
      setState(() => _submitError = 'Satuan dasar wajib dipilih');
      return;
    }

    final units = _parseNum(_unitsPerPurchaseCtrl.text) ?? 0;
    // Isi per satuan beli > 0 — validasi klien SEBELUM menyentuh jaringan,
    // memakai fungsi murni Task 5 (jangan duplikasi ambangnya di sini).
    final unitsErr = unitsPerPurchaseError(units);
    if (unitsErr != null) {
      setState(() => _submitError = unitsErr);
      return;
    }

    final price = _parseNum(_purchasePriceCtrl.text) ?? 0;
    final minStock = _parseNum(_minStockCtrl.text);

    setState(() => _saving = true);
    try {
      final repo = widget.ref.read(stockRepositoryProvider);
      if (_isEditing) {
        await repo.updateIngredient(
          widget.editing!.id,
          name: _nameCtrl.text,
          baseUnit: _baseUnit,
          purchaseUnit: _purchaseUnitCtrl.text,
          unitsPerPurchase: units,
          purchasePrice: price,
          minStock: minStock,
          abcClass: _abcClass,
        );
      } else {
        await repo.createIngredient(
          name: _nameCtrl.text,
          baseUnit: _baseUnit!,
          purchaseUnit: _purchaseUnitCtrl.text,
          unitsPerPurchase: units,
          purchasePrice: price,
          minStock: minStock,
          abcClass: _abcClass,
        );
      }
      widget.ref.invalidate(ingredientsProvider);
      // HppComparisonScreen (layar hub) bisa tetap ter-mount di bawah lewat
      // "Kelola Bahan" — tanpa ini HPP/selisih di sana tetap basi sampai
      // pull-to-refresh manual walau harga bahan baru saja diubah (temuan
      // I-1, review whole-branch feat/stok-fase-a; sama pola dengan
      // RecipeScreen._save()).
      widget.ref.invalidate(hppComparisonProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      // Pesan ApiException sudah Bahasa Indonesia, siap tampil apa adanya
      // (409 INGREDIENT_DUPLICATE_NAME / INGREDIENT_INACTIVE_EXISTS, 404
      // INGREDIENT_NOT_FOUND, 400 EMPTY_PATCH/validasi) — sama pola dengan
      // `_AddFixedCostSheet`.
      if (mounted) setState(() => _submitError = e.message);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Ubah Bahan' : 'Tambah Bahan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _baseUnit,
                decoration: const InputDecoration(labelText: 'Satuan dasar'),
                items: const [
                  DropdownMenuItem(value: 'g', child: Text('gram (g)')),
                  DropdownMenuItem(value: 'ml', child: Text('mililiter (ml)')),
                  DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                ],
                onChanged: (v) => setState(() => _baseUnit = v),
                validator: (v) => v == null ? 'Satuan dasar wajib dipilih' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchaseUnitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Satuan beli',
                  hintText: 'mis. kg, liter, botol, dus',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Satuan beli wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitsPerPurchaseCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Isi per satuan beli',
                  hintText: 'dalam satuan dasar, mis. 1000 untuk 1 kg = 1000 gram',
                ),
                validator: (v) {
                  final n = _parseNum(v ?? '');
                  if (n == null) return 'Isi per satuan beli wajib diisi';
                  return unitsPerPurchaseError(n);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchasePriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Harga per satuan beli (Rp)'),
                validator: (v) {
                  final n = _parseNum(v ?? '');
                  if (n == null || n < 0) return 'Harga per satuan beli wajib diisi';
                  return null;
                },
              ),
              if (preview != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Harga per satuan dasar: $preview',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _abcClass,
                decoration: const InputDecoration(labelText: 'Golongan ABC'),
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('A')),
                  DropdownMenuItem(value: 'B', child: Text('B')),
                  DropdownMenuItem(value: 'C', child: Text('C')),
                ],
                onChanged: (v) => setState(() => _abcClass = v ?? 'C'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minStockCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Stok minimum (opsional)'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final n = _parseNum(t);
                  if (n == null || n < 0) return 'Stok minimum harus angka ≥ 0';
                  return null;
                },
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
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
