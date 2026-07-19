import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../data/customer_segment_repository.dart';

/// Warna penanda tiap segmen (untuk pindai cepat).
Color _segColor(String key) {
  switch (key) {
    case 'vip':
      return AppColors.amberDark;
    case 'loyal':
      return AppColors.success;
    case 'baru':
      return AppColors.espresso;
    case 'berisiko':
      return AppColors.warning;
    case 'hilang':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

/// (Admin) Segmentasi pelanggan RFM + kirim promo tertarget.
class CustomerSegmentsScreen extends ConsumerWidget {
  const CustomerSegmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerSegmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Segmen Pelanggan')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat segmen.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.invalidate(customerSegmentsProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => ref.invalidate(customerSegmentsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  Icon(Icons.groups_rounded,
                      color: AppColors.espresso, size: 22),
                  const SizedBox(width: 10),
                  Text('${data.totalCustomers} pelanggan',
                      style: AppTextStyles.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _compose(context, ref, 'all', 'Semua'),
                    icon: const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Promo ke semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...data.segments.map((s) => _SegmentCard(
                    segment: s,
                    onTap: () => _openSegment(context, ref, s),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _openSegment(
      BuildContext context, WidgetRef ref, CustomerSegment s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SegmentSheet(
        segment: s,
        onBroadcast: () {
          Navigator.pop(context);
          _compose(context, ref, s.key, s.label);
        },
      ),
    );
  }

  Future<void> _compose(
      BuildContext context, WidgetRef ref, String segKey, String segLabel) async {
    final titleC = TextEditingController(text: 'Promo Spesial ☕');
    final bodyC = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: Text('Kirim Promo — $segLabel',
            style: AppTextStyles.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            TextField(
              controller: bodyC,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Pesan'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirim')),
        ],
      ),
    );
    if (send != true) return;
    final title = titleC.text.trim();
    final body = bodyC.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Mengirim…')));
    try {
      final sent = await ref
          .read(customerSegmentRepositoryProvider)
          .broadcast(segment: segKey, title: title, body: body);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Promo terkirim ke $sent pelanggan')));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal mengirim promo.')));
    }
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment, required this.onTap});
  final CustomerSegment segment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _segColor(segment.key);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('${segment.count}',
                    style: AppTextStyles.titleMedium.copyWith(color: color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(segment.label, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(segment.description,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentSheet extends StatelessWidget {
  const _SegmentSheet({required this.segment, required this.onBroadcast});
  final CustomerSegment segment;
  final VoidCallback onBroadcast;

  @override
  Widget build(BuildContext context) {
    final color = _segColor(segment.key);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('${segment.label} · ${segment.count}',
                    style: AppTextStyles.titleLarge),
              ],
            ),
          ),
          Flexible(
            child: segment.customers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text('Belum ada pelanggan di segmen ini.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    itemCount: segment.customers.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, i) => _CustomerRow(c: segment.customers[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: segment.count == 0 ? null : onBroadcast,
                icon: const Icon(Icons.campaign_rounded, size: 20),
                label: Text('Kirim Promo ke ${segment.label}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.espresso,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.c});
  final SegmentCustomer c;

  @override
  Widget build(BuildContext context) {
    final recency = c.recencyDays == null
        ? 'belum pesan'
        : '${c.recencyDays}h lalu';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: AppTextStyles.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${c.frequency}× · $recency',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(Formatters.rupiah(c.monetary),
              style: AppTextStyles.label.copyWith(color: AppColors.amberDark)),
        ],
      ),
    );
  }
}
