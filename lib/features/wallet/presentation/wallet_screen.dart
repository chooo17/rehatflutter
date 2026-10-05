import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../data/wallet_repository.dart';

/// Dompet pelanggan: saldo, top-up (via DOKU), & riwayat transaksi.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const _amounts = [20000, 50000, 100000, 200000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saldo Saya')),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat saldo.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.invalidate(walletProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (w) => RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => ref.invalidate(walletProvider),
          // Layar lebar: saldo + isi saldo | riwayat berdampingan.
          child: AdaptiveColumns(
            narrowPadding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            widePadding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            leftWidth: 420,
            narrowGap: 24,
            left: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.espresso,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo Rehat',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.crema)),
                    const SizedBox(height: 6),
                    Text(Formatters.rupiah(w.balance),
                        style: AppTextStyles.displayMedium
                            .copyWith(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('Isi saldo', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final amt in _amounts)
                    _TopupChip(
                      amount: amt,
                      onTap: () => _topup(context, ref, amt),
                    ),
                ],
              ),
            ],
            right: [
              Text('Riwayat', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              if (w.transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Belum ada transaksi.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...w.transactions.map((t) => _TxnRow(txn: t)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _topup(BuildContext context, WidgetRef ref, int amount) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Menyiapkan pembayaran…')));
    try {
      final url = await ref.read(walletRepositoryProvider).topup(amount);
      if (url.isEmpty) throw Exception('no url');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text(
                'Selesaikan pembayaran di DOKU. Saldo bertambah otomatis setelah lunas — tarik untuk menyegarkan.')));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal memulai top-up.')));
    }
  }
}

class _TopupChip extends StatelessWidget {
  const _TopupChip({required this.amount, required this.onTap});
  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Isi saldo ${Formatters.rupiah(amount)}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber, width: 1.4),
            ),
            child: Text('+ ${Formatters.rupiah(amount)}',
                style:
                    AppTextStyles.label.copyWith(color: AppColors.amberDark)),
          ),
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});
  final WalletTxn txn;

  @override
  Widget build(BuildContext context) {
    final positive = txn.amount >= 0;
    final label = switch (txn.type) {
      'topup' => 'Top-up saldo',
      'payment' => 'Bayar pesanan',
      'refund' => 'Pengembalian',
      'referral_bonus' => 'Bonus referral',
      _ => txn.description.isNotEmpty ? txn.description : 'Transaksi',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyLarge),
                Text(Formatters.tanggalJam(txn.createdAt),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : '-'}${Formatters.rupiah(txn.amount.abs())}',
            style: AppTextStyles.label.copyWith(
                color: positive ? AppColors.success : AppColors.error),
          ),
        ],
      ),
    );
  }
}
