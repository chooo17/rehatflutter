import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery_models.dart';
import '../../../shared/models/order_model.dart';
import '../data/delivery_repository.dart';
import 'widgets/delivery_info_card.dart' show waNumber;

/// Layar kurir: saklar bertugas, antaran menunggu & antaranku.
class CourierScreen extends ConsumerStatefulWidget {
  const CourierScreen({super.key});
  @override
  ConsumerState<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends ConsumerState<CourierScreen> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => ref.invalidate(courierDeliveriesProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      ref.invalidate(courierDeliveriesProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fail(OrderModel o) async {
    final ctrl = TextEditingController();
    String? reason;
    try {
      reason = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Antaran #${o.queueNumber} gagal?'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Alasan (mis. pelanggan tidak bisa dihubungi)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Laporkan')),
          ],
        ),
      );
    } finally {
      // Tunda: animasi tutup dialog masih memakai controller sesaat.
      Future.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    }
    if (reason == null || reason.length < 3) return;
    await _run(() => ref.read(deliveryRepositoryProvider).markFailed(o.id, reason!), 'Dilaporkan ke admin');
  }

  @override
  Widget build(BuildContext context) {
    // 403 = bukan kurir / akses dicabut: percuma polling terus.
    ref.listen(courierDeliveriesProvider, (prev, next) {
      final e = next.error;
      if (next.hasError && e is ApiException && e.statusCode == 403) _timer?.cancel();
    });
    final async = ref.watch(courierDeliveriesProvider);
    final repo = ref.read(deliveryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Antaran')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(onPressed: () => ref.invalidate(courierDeliveriesProvider), child: Text(e is ApiException ? e.message : 'Gagal memuat. Coba lagi')),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(courierDeliveriesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SwitchListTile(
                value: d.onDuty,
                onChanged: _busy ? null : (v) => _run(() => repo.setDuty(v), v ? 'Kamu bertugas' : 'Selesai bertugas'),
                title: Text(d.onDuty ? 'Saya bertugas' : 'Tidak bertugas', style: AppTextStyles.titleMedium),
                subtitle: Text('Terkirim hari ini: ${d.deliveredToday}'),
              ),
              const SizedBox(height: 8),
              Text('Antaranku', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              if (d.mine.isEmpty) const Text('Belum ada antaran yang kamu bawa.'),
              for (final o in d.mine)
                _DeliveryCard(
                  order: o,
                  actions: [
                    if (o.deliveryStatus == DeliveryStatus.assigned)
                      FilledButton(onPressed: _busy ? null : () => _run(() => repo.markOnTheWay(o.id), 'Selamat mengantar!'), child: const Text('Berangkat')),
                    if (o.deliveryStatus == DeliveryStatus.onTheWay)
                      FilledButton(onPressed: _busy ? null : () => _run(() => repo.markDelivered(o.id), 'Antaran selesai'), child: const Text('Terkirim')),
                    TextButton(onPressed: _busy ? null : () => _fail(o), child: const Text('Gagal')),
                  ],
                ),
              const SizedBox(height: 20),
              Text('Menunggu diambil', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              if (!d.onDuty) const Text('Nyalakan "Saya bertugas" untuk melihat & mengambil antaran.')
              else if (d.waiting.isEmpty) const Text('Belum ada antaran baru.'),
              for (final o in d.waiting)
                _DeliveryCard(
                  order: o,
                  actions: [
                    FilledButton(onPressed: _busy ? null : () => _run(() => repo.claim(o.id), 'Antaran diambil'), child: const Text('Ambil antaran')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order, required this.actions});
  final OrderModel order;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final a = order.deliveryAddress;
    final items = order.items.map((i) => '${i.quantity}x ${i.name}').join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#${order.queueNumber}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.amberDark)),
              const Spacer(),
              if (order.deliveryDistanceM != null)
                Text('±${(order.deliveryDistanceM! / 1000).toStringAsFixed(1)} km', style: AppTextStyles.bodySmall),
            ]),
            if (a != null) ...[
              const SizedBox(height: 6),
              Text('${a.recipientName} • ${a.recipientPhone}', style: AppTextStyles.label),
              Text(a.addressText, style: AppTextStyles.bodyMedium),
              if (a.notes != null) Text(a.notes!, style: AppTextStyles.bodySmall),
            ],
            const SizedBox(height: 6),
            Text(items, style: AppTextStyles.bodySmall),
            Text('Sudah dibayar • ${Formatters.rupiah(order.total)}', style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (a != null) ...[
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(a.mapsUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.map_outlined), label: const Text('Peta')),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${a.recipientPhone}')),
                  icon: const Icon(Icons.call_outlined), label: const Text('Telepon')),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/${waNumber(a.recipientPhone)}'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.chat_outlined), label: const Text('WA')),
              ],
              ...actions,
            ]),
          ],
        ),
      ),
    );
  }
}
