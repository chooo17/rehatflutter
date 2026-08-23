import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../menu/data/menu_repository.dart';
import '../data/admin_report_repository.dart';

/// (Admin) Kelola HPP (harga modal) tiap menu → dasar margin & laba riil.
class AdminMenuCostScreen extends ConsumerWidget {
  const AdminMenuCostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allMenuItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('HPP & Margin Menu')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat menu.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.invalidate(allMenuItemsProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (items) {
          final belumIsi = items.where((i) => i.costPrice == 0).length;
          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(allMenuItemsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) return _Hint(belumIsi: belumIsi, total: items.length);
                return _CostRow(item: items[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.belumIsi, required this.total});
  final int belumIsi;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.crema,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.amberDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              belumIsi == 0
                  ? 'Semua $total menu sudah punya HPP. Laba di dashboard kini riil.'
                  : '$belumIsi dari $total menu belum diisi HPP. Isi agar laba akurat.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends ConsumerStatefulWidget {
  const _CostRow({required this.item});
  final MenuItemModel item;

  @override
  ConsumerState<_CostRow> createState() => _CostRowState();
}

class _CostRowState extends ConsumerState<_CostRow> {
  bool _saving = false;

  Future<void> _edit() async {
    final item = widget.item;
    final controller =
        TextEditingController(text: item.costPrice > 0 ? '${item.costPrice}' : '');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: Text('HPP — ${item.name}', style: AppTextStyles.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Harga jual: ${Formatters.rupiah(item.price)}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Harga modal (Rp)',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == null || result == item.costPrice) return;
    await _save(result);
  }

  Future<void> _save(int cost) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(menuRepositoryProvider)
          .updateItem(widget.item.id, costPrice: cost);
      // Segarkan menu & laporan agar margin ikut ter-update.
      ref.invalidate(allMenuItemsProvider);
      ref.invalidate(menuCatalogProvider);
      ref.invalidate(salesReportProvider);
      ref.invalidate(salesCalendarProvider);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('HPP "${widget.item.name}" disimpan')));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal menyimpan HPP.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasCost = item.costPrice > 0;
    final margin = item.marginPct;
    final marginColor = !hasCost
        ? AppColors.textSecondary
        : (margin != null && margin >= 50)
            ? AppColors.success
            : (margin != null && margin >= 25)
                ? AppColors.amberDark
                : AppColors.error;
    return GestureDetector(
      onTap: _saving ? null : _edit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    'Jual ${Formatters.rupiah(item.price)} · '
                    'Modal ${hasCost ? Formatters.rupiah(item.costPrice) : '—'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (_saving)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: AppColors.amber))
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: marginColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasCost ? 'Margin ${margin ?? 0}%' : 'Set HPP',
                  style: AppTextStyles.caption.copyWith(
                      color: marginColor, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
