import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/analytics/analytics_service.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/network/api_exception.dart';
import '../data/wallet_repository.dart';

/// Program referral: bagikan kode, ajak teman, kedua pihak dapat voucher.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(referralProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajak Teman')),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat kode referral.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.invalidate(referralProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        // Layar lebar: kartu undangan | form kode teman berdampingan.
        data: (r) => AdaptiveColumns(
          narrowPadding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          widePadding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
          narrowGap: 24,
          left: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.crema,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.card_giftcard_rounded,
                      color: AppColors.amberDark, size: 40),
                  const SizedBox(height: 12),
                  Text('Ajak teman, dapat diskon ${r.rewardPct}%',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Kamu & temanmu sama-sama dapat voucher ${r.rewardPct}% saat mereka pakai kodemu.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.amber, width: 1.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SelectableText(r.code,
                            style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.espresso, letterSpacing: 2)),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Salin kode',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: r.code));
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(
                                  content: Text('Kode disalin')));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${r.referredCount} teman sudah bergabung',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Analytics.referralShare();
                Share.share(
                    'Pakai kode ${r.code} di aplikasi Rehat Coffeehouse, kita berdua dapat diskon ${r.rewardPct}%! ☕');
              },
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Bagikan kode'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.espresso,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
          right: [
            // Pemisah hanya saat ditumpuk (mobile).
            if (MediaQuery.sizeOf(context).width < 900) ...[
              const Divider(),
              const SizedBox(height: 16),
            ],
            Text('Punya kode teman?', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            _ApplyCodeField(
              onApplied: () => ref.invalidate(referralProvider),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyCodeField extends ConsumerStatefulWidget {
  const _ApplyCodeField({required this.onApplied});
  final VoidCallback onApplied;

  @override
  ConsumerState<_ApplyCodeField> createState() => _ApplyCodeFieldState();
}

class _ApplyCodeFieldState extends ConsumerState<_ApplyCodeField> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _c.text.trim();
    if (code.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(walletRepositoryProvider).applyReferral(code);
      widget.onApplied();
      if (!mounted) return;
      _c.clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Kode diterapkan! Voucher masuk ke tab Loyalti.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal menerapkan kode.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Masukkan kode'),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _busy ? null : _apply,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white))
              : const Text('Pakai'),
        ),
      ],
    );
  }
}
