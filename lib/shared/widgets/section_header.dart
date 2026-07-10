import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Judul bagian dengan tombol "Lihat semua" opsional.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(title, style: AppTextStyles.displaySmall),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              children: [
                Text(actionLabel!),
                Icon(Icons.chevron_right, size: 18, color: AppColors.amberDark),
              ],
            ),
          ),
      ],
    );
  }
}
