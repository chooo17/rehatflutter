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

/// (Admin) Kelola menu: tambah menu baru, ubah detail, aktif/nonaktifkan.
/// Gambar diatur di layar "Kelola Gambar Menu" yang terpisah.
class AdminMenuManageScreen extends ConsumerWidget {
  const AdminMenuManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allMenuItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Menu')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tambah Menu',
            style: AppTextStyles.button.copyWith(color: Colors.white)),
        onPressed: () => _openEditor(context, ref, null),
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
        data: (items) => RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => ref.invalidate(allMenuItemsProvider),
          child: ResponsiveListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: items.length,
            minItemWidth: 360,
            maxColumns: 3,
            runSpacing: 10,
            itemBuilder: (_, i) => _MenuRow(
              item: items[i],
              onTap: () => _openEditor(context, ref, items[i]),
            ),
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, MenuItemModel? item) {
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
        child: _MenuEditor(item: item),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});
  final MenuItemModel item;
  final VoidCallback onTap;

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
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Form tambah/ubah menu (modal bottom sheet).
class _MenuEditor extends ConsumerStatefulWidget {
  const _MenuEditor({this.item});
  final MenuItemModel? item;

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
    _categoryId = (it?.categoryId.isNotEmpty ?? false) ? it!.categoryId : null;
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
