import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/neu.dart';
import '../../auth/application/auth_controller.dart';
import '../application/cart_controller.dart';
import '../application/menu_sort.dart';
import '../data/menu_repository.dart';
import 'widgets/cart_icon_button.dart';
import 'widgets/menu_grid_card.dart';

/// Katalog menu: pencarian, filter kategori, dan grid item.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showSortSheet() async {
    final current = ref.read(menuSortProvider);
    final picked = await showModalBottomSheet<MenuSort>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Urutkan', style: AppTextStyles.titleLarge),
            ),
            for (final s in MenuSort.values)
              ListTile(
                leading: Icon(s.icon,
                    color: s == current
                        ? AppColors.amberDark
                        : AppColors.textSecondary),
                title: Text(s.label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight:
                          s == current ? FontWeight.w600 : FontWeight.w400,
                    )),
                trailing: s == current
                    ? Icon(Icons.check_rounded, color: AppColors.amberDark)
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(menuSortProvider.notifier).state = picked;
    }
  }

  /// Tamu menekan aksi pesan → ajak login.
  void _promptLogin() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Masuk dulu untuk memesan'),
        action: SnackBarAction(
          label: 'Masuk',
          onPressed: () => context.goNamed(RouteNames.login),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final menuAsync = ref.watch(menuListProvider);
    final selected = ref.watch(selectedCategoryProvider);
    final isGuest =
        ref.watch(authControllerProvider).status == AuthStatus.guest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: isGuest
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: NeuButton(
                    onPressed: () => context.goNamed(RouteNames.login),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text('Masuk',
                        style: AppTextStyles.button
                            .copyWith(color: AppColors.espresso)),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.favorite_border_rounded,
                      color: AppColors.espresso),
                  tooltip: 'Favorit',
                  onPressed: () => context.pushNamed(RouteNames.favorites),
                ),
                CartIconButton(color: AppColors.espresso),
              ],
      ),
      body: Column(
        children: [
          if (isGuest) _GuestBanner(onLogin: () => context.goNamed(RouteNames.login)),
          // Pencarian + Urutkan -------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: NeuInset(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    radius: 16,
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => ref
                          .read(menuSearchQueryProvider.notifier)
                          .state = v.trim(),
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        hintText: 'Cari kopi, makanan…',
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AppColors.textSecondary, size: 20),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                      .read(menuSearchQueryProvider.notifier)
                                      .state = '';
                                },
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SortButton(
                  active: ref.watch(menuSortProvider) != MenuSort.recommended,
                  onTap: _showSortSheet,
                ),
              ],
            ),
          ),
          // Kategori ------------------------------------------------------
          SizedBox(
            height: 40,
            child: categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (categories) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  final isActive = cat.id == selected;
                  return NeuButton(
                    onPressed: () => ref
                        .read(selectedCategoryProvider.notifier)
                        .state = cat.id,
                    accent: isActive,
                    radius: 20,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      cat.name,
                      style: AppTextStyles.caption.copyWith(
                        color: isActive ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Grid ----------------------------------------------------------
          Expanded(
            child: menuAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.amber)),
              error: (e, _) => _ErrorState(
                onRetry: () => ref.invalidate(menuListProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyState();
                }
                return RefreshIndicator(
                  color: AppColors.amber,
                  onRefresh: () async => ref.invalidate(menuListProvider),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
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
                        onAdd: isGuest
                            ? _promptLogin
                            : () {
                                ref
                                    .read(cartControllerProvider.notifier)
                                    .add(item);
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(
                                    content: Text(
                                        '${item.name} ditambahkan ke keranjang'),
                                  ));
                              },
                      )
                          .animate()
                          .fadeIn(delay: (i * 40).ms, duration: 260.ms)
                          .slideY(
                              begin: 0.12,
                              end: 0,
                              delay: (i * 40).ms,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner mode tamu — mengajak login agar bisa memesan.
class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.crema,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.amberDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Kamu menjelajah sebagai tamu — masuk untuk memesan.',
                style: AppTextStyles.bodySmall),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLogin,
            child: Text('Masuk',
                style:
                    AppTextStyles.label.copyWith(color: AppColors.amberDark)),
          ),
        ],
      ),
    );
  }
}

/// Tombol pemicu sheet urutkan; disorot saat urutan non-default aktif.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.espresso : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppColors.espresso : AppColors.border),
          ),
          child: Icon(Icons.swap_vert_rounded,
              color: active ? AppColors.crema : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.search_off_rounded,
            color: AppColors.textSecondary, size: 40),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Menu tidak ditemukan.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
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
          Text('Gagal memuat menu.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
