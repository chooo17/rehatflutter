import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/models/loyalty_model.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/section_header.dart';
import '../../admin/presentation/widgets/saved_orders_icon_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../../menu/presentation/widgets/cart_icon_button.dart';
import '../../notifications/presentation/widgets/notification_icon_button.dart';
import '../data/home_repository.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/featured_menu_card.dart';
import 'widgets/spin_banner.dart';

/// Beranda: sapaan, kartu poin, banner spin, dan menu unggulan.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final featuredAsync = ref.watch(featuredMenuProvider);

    // Sumber tunggal untuk poin & stamp — sama dengan layar Loyalti agar sinkron.
    final summary = ref.watch(loyaltySummaryProvider).valueOrNull ??
        LoyaltySummary(points: user?.points ?? 0, stamps: user?.stamps ?? 0);
    final filled =
        summary.stampTarget <= 0 ? 0 : summary.stamps % summary.stampTarget;
    final showFull = filled == 0 && summary.stamps > 0;
    final stampLabel =
        '${showFull ? summary.stampTarget : filled}/${summary.stampTarget}';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async {
            ref.invalidate(featuredMenuProvider);
            ref.invalidate(loyaltySummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _Header(
                    greeting: _greeting(),
                    name: user?.name,
                    isAdmin: user?.isAdmin ?? false),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _PointsCard(points: summary.points, stampLabel: stampLabel),
              ),
              const BannerCarousel(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SpinBanner(
                  onTap: () => context.pushNamed(RouteNames.spin),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  title: 'Menu Unggulan',
                  actionLabel: 'Lihat semua',
                  onAction: () => context.goNamed(RouteNames.menu),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 250,
                child: featuredAsync.when(
                  loading: () => const _FeaturedLoading(),
                  error: (e, _) => _FeaturedError(
                    onRetry: () => ref.invalidate(featuredMenuProvider),
                  ),
                  data: (items) => _FeaturedList(items: items),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, this.name, this.isAdmin = false});
  final String greeting;
  final String? name;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                name?.isNotEmpty == true ? name! : 'Sahabat Rehat',
                style: AppTextStyles.displaySmall,
              ),
            ],
          ),
        ),
        // Admin: pintasan ke pesanan belum bayar (disimpan/QRIS menunggu).
        if (isAdmin) SavedOrdersIconButton(color: AppColors.espresso),
        NotificationIconButton(color: AppColors.espresso),
        CartIconButton(color: AppColors.espresso),
      ],
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points, required this.stampLabel});
  final int points;
  final String stampLabel;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Row(
        children: [
          Expanded(
            child: _stat(
              icon: Icons.stars_rounded,
              value: '$points',
              label: 'Poin terkumpul',
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: _stat(
              icon: Icons.local_cafe_rounded,
              value: stampLabel,
              label: 'Stamp kopi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
      {required IconData icon, required String value, required String label}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.amberDark, size: 28),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.textPrimary)),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _FeaturedList extends StatelessWidget {
  const _FeaturedList({required this.items});
  final List<MenuItemModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Belum ada menu unggulan.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, i) => RepaintBoundary(
        child: FeaturedMenuCard(
          item: items[i],
          onTap: () => context.pushNamed(
            RouteNames.menuDetail,
            pathParameters: {'id': items[i].id},
          ),
        ),
      ),
    );
  }
}

class _FeaturedLoading extends StatelessWidget {
  const _FeaturedLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (_, __) => Container(
        width: 168,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 1200.ms,
            color: AppColors.crema,
          ),
    );
  }
}

class _FeaturedError extends StatelessWidget {
  const _FeaturedError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 8),
          Text(
            'Gagal memuat menu.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
