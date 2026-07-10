import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/loyalty_model.dart';
import '../../../shared/models/voucher_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../auth/application/auth_controller.dart';
import '../data/loyalty_repository.dart';

/// Loyalti: poin, stamp card, dan voucher.
class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(loyaltySummaryProvider);
    final vouchersAsync = ref.watch(vouchersProvider);
    final user = ref.watch(authControllerProvider).user;

    // Fallback ke data user bila ringkasan loyalti belum termuat.
    final summary = summaryAsync.valueOrNull ??
        LoyaltySummary(points: user?.points ?? 0, stamps: user?.stamps ?? 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Loyalti')),
      body: RefreshIndicator(
        color: AppColors.amber,
        onRefresh: () async {
          ref.invalidate(loyaltySummaryProvider);
          ref.invalidate(vouchersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _PointsHeader(summary: summary),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.pushNamed(RouteNames.loyaltyHistory),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Riwayat poin'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Stamp Card', style: AppTextStyles.displaySmall),
            const SizedBox(height: 4),
            Text(
              summary.stampsToReward == 0
                  ? 'Stamp penuh! Tukarkan kopi gratismu.'
                  : '${summary.stampsToReward} stamp lagi menuju kopi gratis.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _StampCard(summary: summary),
            const SizedBox(height: 28),
            Text('Voucher Saya', style: AppTextStyles.displaySmall),
            const SizedBox(height: 12),
            vouchersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.amber)),
              ),
              error: (e, _) => _VoucherError(
                onRetry: () => ref.invalidate(vouchersProvider),
              ),
              data: (vouchers) {
                if (vouchers.isEmpty) return const _NoVouchers();
                return Column(
                  children: [
                    for (var i = 0; i < vouchers.length; i++) ...[
                      _VoucherCard(voucher: vouchers[i])
                          .animate()
                          .fadeIn(delay: (i * 50).ms, duration: 260.ms),
                      if (i != vouchers.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsHeader extends StatelessWidget {
  const _PointsHeader({required this.summary});
  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [AppColors.espresso, AppColors.amberDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.amberLight, size: 20),
              const SizedBox(width: 8),
              Text('Member ${summary.tier}',
                  style: AppTextStyles.label.copyWith(color: AppColors.crema)),
            ],
          ),
          const SizedBox(height: 18),
          Text('${summary.points}',
              style: AppTextStyles.displayLarge.copyWith(color: AppColors.crema)),
          Text('Poin tersedia',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.crema.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

class _StampCard extends StatelessWidget {
  const _StampCard({required this.summary});
  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context) {
    final filled = summary.stamps % summary.stampTarget;
    final showFull = filled == 0 && summary.stamps > 0;
    return NeuCard(
      padding: const EdgeInsets.all(18),
      radius: 20,
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.stampTarget,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) {
              final isFilled = showFull || i < filled;
              final isReward = i == summary.stampTarget - 1;
              return Container(
                decoration: BoxDecoration(
                  color: isFilled ? AppColors.amber : AppColors.crema,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFilled ? AppColors.amberDark : AppColors.border,
                  ),
                ),
                child: Icon(
                  isReward
                      ? Icons.card_giftcard_rounded
                      : Icons.local_cafe_rounded,
                  color: isFilled ? AppColors.espresso : AppColors.amberLight,
                  size: 20,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: showFull ? 1.0 : summary.stampProgress,
              minHeight: 8,
              backgroundColor: AppColors.crema,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${showFull ? summary.stampTarget : filled} / ${summary.stampTarget} stamp',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});
  final VoucherModel voucher;

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: voucher.code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Kode ${voucher.code} disalin')));
  }

  @override
  Widget build(BuildContext context) {
    final usable = voucher.isUsable;
    return Opacity(
      opacity: usable ? 1 : 0.55,
      child: NeuCard(
        padding: EdgeInsets.zero,
        radius: 18,
        child: Row(
          children: [
            // Sisi kiri: nilai diskon.
            Container(
              width: 84,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.crema,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(15)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_offer_rounded,
                        color: AppColors.amberDark, size: 22),
                    const SizedBox(height: 4),
                    Text(voucher.valueLabel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleLarge
                            .copyWith(color: AppColors.espresso)),
                  ],
                ),
              ),
            ),
            // Sisi kanan: detail & aksi.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(voucher.title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(voucher.sourceLabel,
                        style: AppTextStyles.bodySmall),
                    if (voucher.expiresAt != null) ...[
                      const SizedBox(height: 2),
                      Text('Berlaku s/d ${Formatters.tanggal(voucher.expiresAt!)}',
                          style: AppTextStyles.caption),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.border,
                                  style: BorderStyle.solid),
                            ),
                            child: Text(voucher.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                )),
                          ),
                        ),
                        _action(context, usable),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, bool usable) {
    if (voucher.isUsed) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text('Terpakai',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      );
    }
    if (voucher.isExpired) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text('Kedaluwarsa',
            style: AppTextStyles.caption.copyWith(color: AppColors.error)),
      );
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.amberDark),
      onPressed: () => _copyCode(context),
      tooltip: 'Salin kode',
    );
  }
}

class _NoVouchers extends StatelessWidget {
  const _NoVouchers();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.local_offer_outlined,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text('Belum ada voucher.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Menangkan voucher lewat permainan Spin di beranda.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _VoucherError extends StatelessWidget {
  const _VoucherError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text('Gagal memuat voucher.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
