// lib/features/delivery/presentation/widgets/delivery_address_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/models/delivery_models.dart';
import '../../../order/application/checkout_controller.dart';
import '../../data/delivery_repository.dart';

/// Alamat pengiriman terpilih + status cek jarak/ongkir (checkout delivery).
class DeliveryAddressSection extends ConsumerWidget {
  const DeliveryAddressSection({super.key});

  Future<void> _addNew(BuildContext context, WidgetRef ref) async {
    final saved = await context.pushNamed<AddressModel>(RouteNames.addressForm);
    if (saved == null) return;
    // Muat ulang daftar dulu supaya alamat baru sudah ada saat dipilih.
    try {
      // ignore: unused_result
      await ref.refresh(addressesProvider.future);
    } catch (_) {}
    await ref.read(checkoutControllerProvider.notifier).selectAddress(saved.id);
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, List<AddressModel> list) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in list)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(a.label),
                subtitle: Text(a.addressText, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(c, a.id),
              ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Tambah alamat baru'),
              onTap: () => Navigator.pop(c, '__new__'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    if (chosen == '__new__') return _addNew(context, ref);
    await ref.read(checkoutControllerProvider.notifier).selectAddress(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutControllerProvider);
    final addrAsync = ref.watch(addressesProvider);
    final list = addrAsync.valueOrNull ?? const <AddressModel>[];
    final selected = list.where((a) => a.id == state.addressId).firstOrNull;
    final q = state.deliveryQuote;

    // Alamat terpilih yang sudah tak ada di daftar → kosongkan pilihan.
    // Hanya saat daftar sudah FINAL (bukan sedang dimuat ulang): sesudah alamat
    // baru disimpan, daftar lama (tanpa alamat itu) masih terpasang selama
    // refresh — jangan sampai pilihan baru ikut terhapus.
    if (addrAsync.hasValue && !addrAsync.isLoading && state.addressId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final latest = ref.read(addressesProvider);
        if (latest.isLoading || !latest.hasValue) return;
        ref.read(checkoutControllerProvider.notifier).syncAddresses(latest.value!);
      });
    }

    if (addrAsync.isLoading && !addrAsync.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    if (addrAsync.hasError && !addrAsync.hasValue) {
      return Row(children: [
        Expanded(
            child: Text('Gagal memuat alamat.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
        TextButton(onPressed: () => ref.invalidate(addressesProvider), child: const Text('Coba lagi')),
      ]);
    }

    if (selected == null) {
      final add = OutlinedButton.icon(
        onPressed: () => _addNew(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah alamat pengiriman'),
      );
      if (state.quoteError == null) return add;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(state.quoteError!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
          TextButton(
              onPressed: () => ref.read(checkoutControllerProvider.notifier).useDelivery(),
              child: const Text('Coba lagi')),
        ]),
        add,
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.location_on_rounded, color: AppColors.amberDark),
              const SizedBox(width: 8),
              Expanded(child: Text(selected.label, style: AppTextStyles.titleMedium)),
              TextButton(onPressed: () => _pick(context, ref, list), child: const Text('Ganti')),
            ]),
            Text(selected.addressText, style: AppTextStyles.bodyMedium),
            if (selected.notes != null) Text(selected.notes!, style: AppTextStyles.bodySmall),
            Text('${selected.recipientName} • ${selected.recipientPhone}', style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            if (state.isQuoting)
              const LinearProgressIndicator()
            else if (q == null && state.quoteError != null)
              Row(children: [
                Expanded(
                    child: Text(state.quoteError!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
                TextButton(
                    onPressed: () => ref.read(checkoutControllerProvider.notifier).refreshQuote(),
                    child: const Text('Coba lagi')),
              ])
            else if (q != null && !q.available)
              Text(q.message ?? 'Alamat ini belum bisa dikirimi.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))
            else if (q != null)
              Text('Jarak ±${q.distanceKmLabel}', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
