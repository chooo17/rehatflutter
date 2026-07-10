import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Placeholder sederhana untuk fitur yang belum diimplementasi.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle = 'Segera hadir.',
    this.showAppBar = true,
  });

  final String title;
  final IconData icon;
  final String subtitle;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.crema,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: AppColors.amberDark, size: 34),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.displaySmall),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
