import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/loyalty_history_model.dart';
import '../data/loyalty_repository.dart';

/// Riwayat transaksi poin loyalitas.
class LoyaltyHistoryScreen extends ConsumerWidget {
  const LoyaltyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loyaltyHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Poin')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(loyaltyHistoryProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(loyaltyHistoryProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 20),
              itemBuilder: (context, i) => _HistoryRow(entry: entries[i]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final LoyaltyHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final earn = entry.isEarn;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.crema,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            earn ? Icons.add_rounded : Icons.remove_rounded,
            color: earn ? AppColors.success : AppColors.amberDark,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.description.isEmpty ? 'Transaksi poin' : entry.description,
                  style: AppTextStyles.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (entry.createdAt != null) ...[
                const SizedBox(height: 2),
                Text(Formatters.tanggalJam(entry.createdAt!),
                    style: AppTextStyles.bodySmall),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${earn ? '+' : '-'}${entry.amount.abs()}',
          style: AppTextStyles.titleMedium.copyWith(
            color: earn ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              color: AppColors.textSecondary, size: 40),
          const SizedBox(height: 12),
          Text('Belum ada riwayat poin',
              style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text('Poin dari pesananmu akan tercatat di sini.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text('Gagal memuat riwayat poin.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
