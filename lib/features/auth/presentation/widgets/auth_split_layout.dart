import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Tata letak layar auth. Layar lebar (≥ 900): split-screen — panel brand di
/// kiri, form di kanan — bukan form sempit di tengah dengan ruang kosong di
/// kiri-kanan. Layar sempit: [child] apa adanya (tampilan HP tak berubah).
class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900) return child;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: _BrandPanel()),
          Expanded(child: child),
        ],
      );
    });
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _perks = [
    (Icons.local_cafe_rounded, 'Pesan dari mana saja, ambil tanpa antre'),
    (Icons.stars_rounded, 'Kumpulkan poin di setiap pesanan'),
    (Icons.card_giftcard_rounded, '9 stamp = 1 kopi gratis'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.espresso, AppColors.amberDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.crema.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_cafe_rounded,
                color: AppColors.amber, size: 30),
          ),
          const Spacer(),
          Text('Rehat\nCoffeehouse',
              style: AppTextStyles.displayLarge
                  .copyWith(color: AppColors.crema, height: 1.05)),
          const SizedBox(height: 16),
          Text(
            'Kopi favoritmu, sekali ketuk.',
            style: AppTextStyles.titleLarge
                .copyWith(color: AppColors.crema.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 32),
          for (final (icon, text) in _perks) ...[
            Row(
              children: [
                Icon(icon, color: AppColors.amber, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text,
                      style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.crema.withValues(alpha: 0.9))),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}
