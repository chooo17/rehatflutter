import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Menampilkan / memilih rating bintang (1–5).
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.color = AppColors.amber,
    this.onChanged,
  });

  /// Rating saat ini (boleh pecahan untuk tampilan, mis. 4.5).
  final double rating;
  final double size;
  final Color color;

  /// Bila diisi, bintang dapat ditekan (mode input).
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final index = i + 1;
        final IconData icon;
        if (rating >= index) {
          icon = Icons.star_rounded;
        } else if (rating >= index - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        final star = Icon(icon, size: size, color: color);
        if (onChanged == null) return star;
        return GestureDetector(
          onTap: () => onChanged!(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              rating >= index ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: color,
            ),
          ),
        );
      }),
    );
  }
}
