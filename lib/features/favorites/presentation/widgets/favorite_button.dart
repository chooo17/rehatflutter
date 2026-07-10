import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/menu_item_model.dart';
import '../../application/favorites_controller.dart';

/// Ikon hati untuk menandai/menghapus menu favorit (dengan pembaruan optimistis).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.item,
    this.size = 22,
    this.background = false,
  });

  final MenuItemModel item;
  final double size;

  /// Bila true, ikon diberi latar bulat (untuk ditumpuk di atas gambar).
  final bool background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteIdsProvider).contains(item.id);

    final icon = Icon(
      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: isFav ? AppColors.error : (background ? AppColors.espresso : AppColors.textSecondary),
      size: size,
    );

    return Semantics(
      button: true,
      label: isFav ? 'Hapus dari favorit' : 'Tambah ke favorit',
      child: InkResponse(
        onTap: () => _toggle(context, ref, isFav),
        radius: size,
        child: background
            ? Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: icon,
              )
            : Padding(padding: const EdgeInsets.all(4), child: icon),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool wasFav) async {
    try {
      await ref.read(favoritesControllerProvider.notifier).toggle(item);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui favorit. Coba lagi.')),
        );
      }
    }
  }
}
