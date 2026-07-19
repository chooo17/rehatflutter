import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';

/// Kotak placeholder dengan efek shimmer — dasar semua skeleton loader.
/// Menghormati "kurangi gerak" OS (aksesibilitas): shimmer dimatikan bila
/// pengguna menonaktifkan animasi.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.crema,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    // Hormati preferensi "kurangi gerak".
    if (MediaQuery.of(context).disableAnimations) return box;
    return box
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1100.ms, color: AppColors.surface);
  }
}

/// Skeleton grid yang meniru layout kartu menu saat memuat — pengganti
/// spinner agar terasa lebih cepat & konsisten.
class MenuGridSkeleton extends StatelessWidget {
  const MenuGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.66,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const _MenuCardSkeleton(),
    );
  }
}

class _MenuCardSkeleton extends StatelessWidget {
  const _MenuCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: SkeletonBox(width: double.infinity, radius: 16)),
        SizedBox(height: 10),
        SkeletonBox(width: 110, height: 13, radius: 6),
        SizedBox(height: 8),
        SkeletonBox(width: 70, height: 13, radius: 6),
      ],
    );
  }
}
