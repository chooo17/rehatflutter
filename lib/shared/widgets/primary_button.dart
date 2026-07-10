import 'package:flutter/material.dart';

import '../../core/constants/app_text_styles.dart';
import 'neu.dart';

/// Tombol utama neumorphic (aksen amber) dengan dukungan state loading.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return NeuButton(
      expand: true,
      accent: true,
      onPressed: isLoading ? null : onPressed,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: AppTextStyles.button.copyWith(color: Colors.white)),
              ],
            ),
    );
  }
}
