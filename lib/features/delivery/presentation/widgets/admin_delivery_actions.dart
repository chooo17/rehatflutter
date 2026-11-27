import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/models/delivery_models.dart';
import '../../../../shared/models/order_model.dart';
import '../../../order/data/order_repository.dart';
import '../../data/delivery_repository.dart';

/// Admin: pilihkan/pindahkan kurir & batalkan + refund ke Saldo Rehat.
class AdminDeliveryActions extends ConsumerWidget {
  const AdminDeliveryActions({super.key, required this.order});
  final OrderModel order;

  bool get _active =>
      (order.status == OrderStatus.paid || order.status == OrderStatus.preparing) &&
      order.deliveryStatus != DeliveryStatus.delivered &&
      order.deliveryStatus != DeliveryStatus.cancelled;

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminOrderDetailProvider(order.id));
    ref.invalidate(adminOrdersProvider);
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    List<CourierInfo> couriers;
    try {
      couriers = await ref.read(couriersProvider.future);
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
      return;
    }
    if (!context.mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Pilih kurir'),
        children: [
          if (couriers.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada kurir.')),
          for (final k in couriers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, k.id),
              child: Text('${k.name} ${k.onDuty ? '• bertugas' : '• tidak bertugas'}'),
            ),
        ],
      ),
    );
    if (id == null) return;
    try {
      await ref.read(deliveryRepositoryProvider).assignCourier(order.id, id);
      _refresh(ref);
      if (context.mounted) _toast(context, 'Kurir ditetapkan');
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Batalkan & refund ke Saldo Rehat?'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Alasan (wajib)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Refund')),
        ],
      ),
    );
    if (reason == null || reason.length < 3) {
      if (reason != null && context.mounted) _toast(context, 'Alasan minimal 3 karakter');
      return;
    }
    try {
      await ref.read(deliveryRepositoryProvider).refundDelivery(order.id, reason);
      _refresh(ref);
      if (context.mounted) _toast(context, 'Pesanan dibatalkan & dana masuk Saldo Rehat pelanggan');
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!order.isDelivery || !_active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _assign(context, ref),
            icon: const Icon(Icons.person_pin_circle_outlined),
            label: Text(order.courierName == null ? 'Pilihkan kurir' : 'Pindahkan kurir'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _refund(context, ref),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Batal & refund'),
          ),
        ),
      ]),
    );
  }
}
