import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Banner promosi menuju permainan Spin the Wheel.
class SpinBanner extends StatelessWidget {
  const SpinBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [AppColors.espresso, AppColors.amberDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'GRATIS HARI INI',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.amberLight,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Putar & Menang',
                    style: AppTextStyles.displaySmall
                        .copyWith(color: AppColors.crema),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coba peruntunganmu, menangkan kopi gratis & voucher.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.crema.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Main sekarang',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.espresso),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: AppColors.espresso, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Ikon statis — animasi berputar dihapus agar beranda lebih ringan.
            Icon(
              Icons.casino_rounded,
              color: AppColors.amberLight.withValues(alpha: 0.9),
              size: 72,
            ),
          ],
        ),
      ),
    );
  }
}
