import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/neu.dart';
import '../../menu/application/cart_controller.dart';
import '../../menu/presentation/widgets/cart_icon_button.dart';
import '../../menu/presentation/widgets/menu_grid_card.dart';
import '../application/favorites_controller.dart';

/// Daftar menu favorit pengguna.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorit'),
        actions: [CartIconButton(color: AppColors.espresso)],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(favoritesControllerProvider),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(favoritesControllerProvider),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.menuColumns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return MenuGridCard(
                  item: item,
                  onTap: () => context.pushNamed(
                    RouteNames.menuDetail,
                    pathParameters: {'id': item.id},
                  ),
                  onAdd: () {
                    ref.read(cartControllerProvider.notifier).add(item);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('${item.name} ditambahkan ke keranjang'),
                      ));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuCard(
            padding: EdgeInsets.zero,
            radius: 24,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Icon(Icons.favorite_border_rounded,
                  color: AppColors.amberDark, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          Text('Belum ada favorit', style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Ketuk ikon hati pada menu untuk menyimpannya di sini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text('Gagal memuat favorit.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
