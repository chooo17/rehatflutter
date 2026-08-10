import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/neu.dart';
import '../../application/finance_overview_view.dart';

/// Satu kartu amplop alokasi: label, ikon, saldo, dan tombol tarik.
///
/// Saldo negatif diwarnai [AppColors.error] dan diberi keterangan defisit —
/// **TIDAK di-clamp ke 0** (overspend harus terlihat, itu sinyal nyata).
class BucketCard extends StatelessWidget {
  const BucketCard({
    super.key,
    required this.label,
    required this.icon,
    required this.balance,
    required this.withdrawState,
    required this.onWithdraw,
  });

  final String label;
  final IconData icon;
  final int balance;
  final WithdrawButtonState withdrawState;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final negative = bucketIsNegative(balance);
    final balanceColor = negative ? AppColors.error : AppColors.espresso;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.rupiah(bucketDisplayBalance(balance)),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: balanceColor, fontWeight: FontWeight.bold),
          ),
          if (negative)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Defisit ${Formatters.rupiah(balance.abs())} — pos ini kurang.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: NeuButton(
              onPressed: withdrawState.enabled ? onWithdraw : null,
              child: const Text('Tarik'),
            ),
          ),
          if (!withdrawState.enabled && withdrawState.blockedReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                withdrawState.blockedReason!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
