import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/menu_item_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/neu.dart';
import '../../../menu/data/menu_repository.dart';
import '../../application/order_edit_cart.dart';
import '../../data/order_repository.dart';

/// Buka editor item pesanan tersimpan. Mengembalikan `true` bila ada perubahan
/// yang tersimpan (pemanggil menyegarkan detail).
Future<bool> showEditOrderSheet(BuildContext context, OrderModel order) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EditOrderBody(order: order),
  );
  return result ?? false;
}

class _EditOrderBody extends ConsumerStatefulWidget {
  const _EditOrderBody({required this.order});
  final OrderModel order;

  @override
  ConsumerState<_EditOrderBody> createState() => _EditOrderBodyState();
}

class _EditOrderBodyState extends ConsumerState<_EditOrderBody> {
  late final OrderEditCart _cart;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cart = OrderEditCart([
      for (final it in widget.order.items)
        EditLine(
          menuItemId: it.menuItemId,
          name: it.name,
          unitPrice: it.price,
          quantity: it.quantity,
          optionSummary: it.customizationSummary,
          customization: _custFrom(it),
        ),
    ]);
  }

  Map<String, dynamic> _custFrom(OrderItemModel it) {
    final m = <String, dynamic>{};
    if (it.size != null) m['size'] = it.size;
    if (it.sugarLevel != null) m['sugar_level'] = it.sugarLevel;
    if (it.temperature != null) m['temperature'] = it.temperature;
    return m;
  }

  void _inc(EditLine it) => setState(() => _cart.inc(it));
  void _dec(EditLine it) => setState(() => _cart.dec(it));
  void _remove(EditLine it) => setState(() => _cart.remove(it));

  Future<void> _addItem() async {
    final picked = await showModalBottomSheet<MenuItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _MenuPickerSheet(),
    );
    if (picked == null) return;
    setState(() => _cart.addMenu(
        menuItemId: picked.id, name: picked.name, unitPrice: picked.price));
  }

  Future<void> _save() async {
    if (_cart.isEmpty || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(orderRepositoryProvider)
          .updateOrderItems(widget.order.id, _cart.toItems());
      if (!mounted) return;
      navigator.pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Pesanan diperbarui ✅')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan. $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('Edit Pesanan', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Flexible(
                child: _cart.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Belum ada item. Tambah minimal 1.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        itemCount: _cart.lines.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (_, i) => _row(_cart.lines[i]),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _addItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amberDark,
                    side: BorderSide(color: AppColors.amberDark),
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Total', style: AppTextStyles.bodyMedium),
                        const Spacer(),
                        Text(Formatters.rupiah(_cart.total),
                            style: AppTextStyles.titleLarge
                                .copyWith(color: AppColors.amberDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    NeuButton(
                      expand: true,
                      accent: true,
                      onPressed: (_cart.isEmpty || _saving) ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white))
                          : Text('Simpan perubahan',
                              style: AppTextStyles.button
                                  .copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(EditLine it) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.name, style: AppTextStyles.titleMedium),
              if (it.optionSummary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(it.optionSummary,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 2),
              Text(Formatters.rupiah(it.subtotal),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.amberDark)),
            ],
          ),
        ),
        _StepButton(icon: Icons.remove_rounded, onTap: () => _dec(it)),
        SizedBox(
          width: 28,
          child: Text('${it.quantity}',
              textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
        ),
        _StepButton(icon: Icons.add_rounded, onTap: () => _inc(it)),
        IconButton(
          onPressed: () => _remove(it),
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.error, size: 20),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.crema,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.espresso),
      ),
    );
  }
}

/// Pemilih menu untuk "Tambah item" — daftar menu + pencarian. Mengembalikan
/// [MenuItemModel] yang dipilih (atau null bila batal).
class _MenuPickerSheet extends ConsumerStatefulWidget {
  const _MenuPickerSheet();

  @override
  ConsumerState<_MenuPickerSheet> createState() => _MenuPickerSheetState();
}

class _MenuPickerSheetState extends ConsumerState<_MenuPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(menuCatalogProvider);
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('Pilih Menu', style: AppTextStyles.titleLarge),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Cari menu…',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppColors.crema,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.amber),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Gagal memuat menu.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                  data: (all) {
                    final list = _query.isEmpty
                        ? all
                        : all
                            .where((m) => m.name.toLowerCase().contains(_query))
                            .toList();
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Menu tak ditemukan.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (_, i) {
                        final m = list[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.name, style: AppTextStyles.bodyLarge),
                          trailing: Text(Formatters.rupiah(m.price),
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.amberDark)),
                          onTap: () => Navigator.of(context).pop(m),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
