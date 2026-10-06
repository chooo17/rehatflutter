import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/menu_category_model.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../menu/data/menu_repository.dart';

/// (Admin) Kelola menu: tambah/ubah/hapus menu, aktif/nonaktifkan, filter per
/// kategori & tambah kategori. Gambar diatur di layar "Kelola Gambar Menu".
class AdminMenuManageScreen extends ConsumerStatefulWidget {
  const AdminMenuManageScreen({super.key});

  @override
  ConsumerState<AdminMenuManageScreen> createState() =>
      _AdminMenuManageScreenState();
}

class _AdminMenuManageScreenState extends ConsumerState<AdminMenuManageScreen> {
  /// Id kategori yang sedang difilter ('' = Semua).
  String _categoryId = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allMenuItemsProvider);
    final cats = ref.watch(menuCategoriesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Menu')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tambah Menu',
            style: AppTextStyles.button.copyWith(color: Colors.white)),
        onPressed: () => _openEditor(null),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(allMenuItemsProvider),
            child: const Text('Gagal memuat. Coba lagi'),
          ),
        ),
        data: (all) {
          // Kategori terpilih bisa lenyap (mis. dinonaktifkan di DB) → Semua.
          final active = cats.any((c) => c.id == _categoryId && !c.isAll)
              ? _categoryId
              : '';
          final items = active.isEmpty
              ? all
              : all.where((m) => m.categoryId == active).toList();
          return Column(
            children: [
              _CategoryFilterBar(
                categories: cats.where((c) => !c.isAll).toList(),
                items: all,
                active: active,
                onPick: (id) => setState(() => _categoryId = id),
                onAdd: _addCategory,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.amber,
                  onRefresh: () async {
                    ref.invalidate(menuCategoriesProvider);
                    ref.invalidate(allMenuItemsProvider);
                  },
                  child: items.isEmpty
                      ? _EmptyCategory(onAdd: () => _openEditor(null))
                      : ResponsiveListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                          itemCount: items.length,
                          minItemWidth: 360,
                          maxColumns: 3,
                          runSpacing: 10,
                          itemBuilder: (_, i) => _MenuRow(
                            item: items[i],
                            onTap: () => _openEditor(items[i]),
                            onDelete: () => _confirmDelete(items[i]),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEditor(MenuItemModel? item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        // Menu baru langsung terisi kategori yang sedang difilter.
        child: _MenuEditor(
            item: item,
            initialCategoryId: _categoryId.isEmpty ? null : _categoryId),
      ),
    );
  }

  Future<void> _confirmDelete(MenuItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${item.name}?'),
        content: const Text(
          'Menu akan hilang dari katalog pelanggan dan dari daftar ini.\n\n'
          'Bila menu ini pernah terjual, datanya diarsipkan supaya riwayat '
          'pesanan & laporan penjualan tetap utuh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final archived =
          await ref.read(menuRepositoryProvider).deleteItem(item.id);
      ref.invalidate(allMenuItemsProvider);
      ref.invalidate(menuCatalogProvider);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(SnackBar(
        content: Text(archived
            ? '${item.name} diarsipkan — riwayat penjualan tetap tersimpan'
            : '${item.name} dihapus'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Gagal menghapus menu.')));
    }
  }

  Future<void> _addCategory() async {
    final cat = await showDialog<MenuCategory>(
      context: context,
      builder: (_) => const _AddCategoryDialog(),
    );
    if (cat == null || !mounted) return;
    ref.invalidate(menuCategoriesProvider);
    ref.invalidate(menuCatalogProvider);
    setState(() => _categoryId = cat.id);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori "${cat.name}" siap dipakai')));
  }
}

/// Baris chip filter kategori (+ jumlah menu) dan chip "Kategori" untuk
/// menambah kategori baru. Gulir horizontal di HP, membungkus di layar lebar.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.items,
    required this.active,
    required this.onPick,
    required this.onAdd,
  });

  final List<MenuCategory> categories;
  final List<MenuItemModel> items;
  final String active;
  final ValueChanged<String> onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final m in items) {
      counts[m.categoryId] = (counts[m.categoryId] ?? 0) + 1;
    }
    Widget chip(String id, String label, int n) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text('$label ($n)'),
            selected: active == id,
            selectedColor: AppColors.amber.withValues(alpha: 0.2),
            onSelected: (_) => onPick(id),
          ),
        );
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          chip('', 'Semua', items.length),
          for (final c in categories) chip(c.id, c.name, counts[c.id] ?? 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Kategori'),
              tooltip: 'Tambah kategori',
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // ListView supaya tarik-untuk-segarkan tetap berfungsi saat kosong.
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 96),
      children: [
        Icon(Icons.restaurant_menu_rounded,
            size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text('Belum ada menu di kategori ini',
            textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
        const SizedBox(height: 4),
        Text('Tambahkan menu pertama — kategorinya langsung terisi.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Menu'),
          ),
        ),
      ],
    );
  }
}

/// Dialog tambah kategori. Mengembalikan [MenuCategory] yang dibuat via `pop`.
class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama kategori wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cat = await ref.read(menuRepositoryProvider).createCategory(name);
      if (mounted) Navigator.of(context).pop(cat);
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Gagal menyimpan kategori.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Kategori'),
      content: TextField(
        controller: _name,
        autofocus: true,
        enabled: !_saving,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Nama kategori *',
          hintText: 'mis. Teh, Dessert',
          errorText: _error,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.item, required this.onTap, required this.onDelete});
  final MenuItemModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: NeuCard(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.name,
                            style: AppTextStyles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (item.isFeatured) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded,
                            size: 16, color: AppColors.amber),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Formatters.rupiah(item.price)} · '
                    '${item.category.isNotEmpty ? item.category : 'tanpa kategori'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (item.isAvailable ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.isAvailable ? 'Tersedia' : 'Nonaktif',
                  style: AppTextStyles.caption.copyWith(
                      color:
                          item.isAvailable ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: 'Hapus menu',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form tambah/ubah menu (modal bottom sheet).
class _MenuEditor extends ConsumerStatefulWidget {
  const _MenuEditor({this.item, this.initialCategoryId});
  final MenuItemModel? item;

  /// Kategori awal untuk menu BARU (kategori yang sedang difilter).
  final String? initialCategoryId;

  @override
  ConsumerState<_MenuEditor> createState() => _MenuEditorState();
}

class _MenuEditorState extends ConsumerState<_MenuEditor> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _sort;
  String? _categoryId;
  late bool _available;
  late bool _featured;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?.name ?? '');
    _desc = TextEditingController(text: it?.description ?? '');
    _price = TextEditingController(text: it != null ? '${it.price}' : '');
    _cost = TextEditingController(
        text: it != null && it.costPrice > 0 ? '${it.costPrice}' : '');
    _sort = TextEditingController(text: '0');
    _categoryId = it == null
        ? widget.initialCategoryId
        : (it.categoryId.isNotEmpty ? it.categoryId : null);
    _available = it?.isAvailable ?? true;
    _featured = it?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _cost.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim()) ?? -1;
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nama wajib diisi.')));
      return;
    }
    if (_categoryId == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Pilih kategori dulu.')));
      return;
    }
    if (price < 0) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Harga tidak valid.')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(menuRepositoryProvider);
    final cost = int.tryParse(_cost.text.trim()) ?? 0;
    final sort = int.tryParse(_sort.text.trim()) ?? 0;
    try {
      if (_isEdit) {
        await repo.updateItem(
          widget.item!.id,
          name: name,
          description: _desc.text.trim(),
          categoryId: _categoryId,
          price: price,
          costPrice: cost,
          sortOrder: sort,
          isAvailable: _available,
          isFeatured: _featured,
        );
      } else {
        await repo.createItem(
          name: name,
          categoryId: _categoryId!,
          price: price,
          costPrice: cost,
          description: _desc.text.trim(),
          sortOrder: sort,
          isAvailable: _available,
          isFeatured: _featured,
        );
      }
      ref.invalidate(allMenuItemsProvider);
      ref.invalidate(menuCatalogProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Menu diperbarui' : 'Menu baru dibuat')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
          .showSnackBar(const SnackBar(content: Text('Gagal menyimpan menu.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(menuCategoriesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(_isEdit ? 'Ubah Menu' : 'Tambah Menu',
                    style: AppTextStyles.titleLarge),
              ),
              const SizedBox(height: 16),
              _field('Nama *', _name, cap: TextCapitalization.words),
              const SizedBox(height: 10),
              cats.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text('Gagal memuat kategori',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
                data: (list) => _categoryDropdown(
                    list.where((c) => !c.isAll).toList()),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _field('Harga *', _price,
                        keyboard: TextInputType.number, digitsOnly: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field('HPP (modal)', _cost,
                        keyboard: TextInputType.number, digitsOnly: true)),
              ]),
              const SizedBox(height: 10),
              _field('Deskripsi', _desc, maxLines: 2),
              const SizedBox(height: 10),
              _field('Urutan tampil', _sort,
                  keyboard: TextInputType.number, digitsOnly: true),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.amber,
                title: Text('Tersedia (tampil ke pelanggan)',
                    style: AppTextStyles.bodyMedium),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.amber,
                title:
                    Text('Unggulan (featured)', style: AppTextStyles.bodyMedium),
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
              ),
              const SizedBox(height: 12),
              NeuButton(
                expand: true,
                accent: true,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white))
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Buat Menu',
                        style:
                            AppTextStyles.button.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryDropdown(List<MenuCategory> list) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Kategori *',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _categoryId,
          hint: const Text('Pilih kategori'),
          items: [
            for (final c in list)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {TextInputType? keyboard,
      bool digitsOnly = false,
      int maxLines = 1,
      TextCapitalization cap = TextCapitalization.none}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      textCapitalization: cap,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
