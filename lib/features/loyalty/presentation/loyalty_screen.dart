import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
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
    final user = ref.watch(currentUserProvider);

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
        child: LayoutBuilder(builder: (context, c) {
          final tier = <Widget>[
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
          ];
          final redeem = <Widget>[
            Text('Tukar Poin jadi Voucher', style: AppTextStyles.displaySmall),
            const SizedBox(height: 4),
            Text(
              'Punya ${summary.points} poin. Tukar jadi voucher diskon untuk checkout.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _RedeemPointsRow(points: summary.points),
          ];
          final stamps = <Widget>[
            Text('Stamp Card', style: AppTextStyles.displaySmall),
            const SizedBox(height: 4),
            Text(
              summary.stampsToReward == 0
                  ? 'Stamp penuh! Tunjukkan ke kasir untuk tukar kopi gratis.'
                  : '${summary.stampsToReward} stamp lagi menuju kopi gratis.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _StampCard(summary: summary),
            if (summary.redeemableRewards > 0) ...[
              const SizedBox(height: 14),
              _RedeemStampButton(count: summary.redeemableRewards),
            ],
          ];
          final vouchers = <Widget>[
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
                return ResponsiveGrid(
                  minItemWidth: 300,
                  maxColumns: 2,
                  children: [
                    for (var i = 0; i < vouchers.length; i++)
                      _VoucherCard(voucher: vouchers[i])
                          .animate()
                          .fadeIn(delay: (i * 50).ms, duration: 260.ms),
                  ],
                );
              },
            ),
          ];

          // Layar lebar: dua kolom (tier + stamp | tukar poin + voucher)
          // agar isi mengisi lebar, bukan satu kolom panjang yang melar.
          if (c.maxWidth >= 900) {
            Widget col(List<Widget> children) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                );
            return ListView(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: col([
                      ...tier,
                      const SizedBox(height: 12),
                      ...stamps,
                    ])),
                    const SizedBox(width: 32),
                    Expanded(
                        child: col([
                      ...redeem,
                      const SizedBox(height: 28),
                      ...vouchers,
                    ])),
                  ],
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              ...tier,
              const SizedBox(height: 20),
              ...redeem,
              const SizedBox(height: 20),
              ...stamps,
              const SizedBox(height: 28),
              ...vouchers,
            ],
          );
        }),
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
              style:
                  AppTextStyles.displayLarge.copyWith(color: AppColors.crema)),
          Text('Poin terkumpul • menentukan tier-mu',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.crema.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

/// Tombol tukar stamp → voucher gratis 1 minuman. Muncul saat hadiah siap.
class _RedeemStampButton extends ConsumerStatefulWidget {
  const _RedeemStampButton({required this.count});
  final int count;

  @override
  ConsumerState<_RedeemStampButton> createState() => _RedeemStampButtonState();
}

class _RedeemStampButtonState extends ConsumerState<_RedeemStampButton> {
  bool _submitting = false;

  Future<void> _redeem() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await ref.read(loyaltyRepositoryProvider).redeemStamp();
      Analytics.redeemStamp();
      // Segarkan ringkasan (stamp berkurang) & daftar voucher (voucher baru).
      ref.invalidate(loyaltySummaryProvider);
      ref.invalidate(vouchersProvider);
      ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text(
                'Voucher gratis 1 minuman dibuat! Tunjukkan ke kasir untuk menukar.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Gagal menukar stamp. Coba lagi.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuButton(
      expand: true,
      accent: true,
      onPressed: _submitting ? null : _redeem,
      child: _submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_cafe_rounded,
                    size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.count > 1
                      ? 'Tukar kopi gratis (${widget.count})'
                      : 'Tukar kopi gratis',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ],
            ),
    );
  }
}

/// Baris 3 opsi tukar poin → voucher diskon (10/20/30%).
class _RedeemPointsRow extends ConsumerStatefulWidget {
  const _RedeemPointsRow({required this.points});
  final int points;

  @override
  ConsumerState<_RedeemPointsRow> createState() => _RedeemPointsRowState();
}

class _RedeemPointsRowState extends ConsumerState<_RedeemPointsRow> {
  // pct → biaya poin (samakan dgn backend POINT_COSTS).
  static const _costs = {10: 200, 20: 400, 30: 600};
  int? _submittingPct;

  Future<void> _redeem(int pct) async {
    if (_submittingPct != null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submittingPct = pct);
    try {
      await ref.read(loyaltyRepositoryProvider).redeemPoints(pct);
      Analytics.redeemPoints(discountPct: pct);
      ref.invalidate(loyaltySummaryProvider);
      ref.invalidate(vouchersProvider);
      ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('Voucher diskon $pct% dibuat! Cek "Voucher Saya".')));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Gagal menukar poin. Coba lagi.')));
    } finally {
      if (mounted) setState(() => _submittingPct = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final pct in _costs.keys) ...[
          Expanded(
            child: _RedeemPointsCard(
              pct: pct,
              cost: _costs[pct]!,
              affordable: widget.points >= _costs[pct]!,
              busy: _submittingPct == pct,
              disabled: _submittingPct != null,
              onTap: () => _redeem(pct),
            ),
          ),
          if (pct != _costs.keys.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _RedeemPointsCard extends StatelessWidget {
  const _RedeemPointsCard({
    required this.pct,
    required this.cost,
    required this.affordable,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final int pct;
  final int cost;
  final bool affordable;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = affordable && !disabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Tukar $cost poin jadi voucher diskon $pct persen',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: NeuCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text('$pct%',
                  style: AppTextStyles.displaySmall.copyWith(
                    color: affordable
                        ? AppColors.amberDark
                        : AppColors.textSecondary,
                  )),
              const SizedBox(height: 4),
              busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: AppColors.amber))
                  : Text('$cost poin',
                      style: AppTextStyles.caption.copyWith(
                        color: affordable
                            ? AppColors.textSecondary
                            : AppColors.error,
                      )),
            ],
          ),
        ),
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
      // Lebar dibatasi: grid 5 kolom aspek 1 membuat lingkaran stamp ikut
      // membesar sebanding lebar layar (≈230px di desktop).
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
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
                        color:
                            isFilled ? AppColors.amberDark : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      isReward
                          ? Icons.card_giftcard_rounded
                          : Icons.local_cafe_rounded,
                      color:
                          isFilled ? AppColors.espresso : AppColors.amberLight,
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
        ),
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
                    Text(voucher.sourceLabel, style: AppTextStyles.bodySmall),
                    if (voucher.expiresAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          'Berlaku s/d ${Formatters.tanggal(voucher.expiresAt!)}',
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text('Terpakai',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }
    if (voucher.isExpired) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.schedule_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 4),
          Text('Kedaluwarsa',
              style: AppTextStyles.caption.copyWith(color: AppColors.error)),
        ]),
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
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
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
