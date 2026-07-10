import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/menu_item_model.dart';
import '../../../../shared/widgets/cart_fly.dart';
import '../../../../shared/widgets/neu.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';

/// Kartu menu untuk tampilan grid katalog.
class MenuGridCard extends StatelessWidget {
  const MenuGridCard({super.key, required this.item, this.onTap, this.onAdd});

  final MenuItemModel item;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                  child: AspectRatio(
                    aspectRatio: 1.3,
                    child: _Image(url: item.imageUrl),
                  ),
                ),
                if (!item.isAvailable)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(17)),
                      ),
                      child: Center(
                        child: Text('Habis',
                            style: AppTextStyles.label
                                .copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: FavoriteButton(item: item, size: 18, background: true),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.rupiah(item.price),
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.amberDark),
                          ),
                        ),
                        Builder(
                          builder: (btnContext) => NeuButton(
                            onPressed: item.isAvailable
                                ? () {
                                    flyToCart(btnContext,
                                        imageUrl: item.imageUrl);
                                    onAdd?.call();
                                  }
                                : null,
                            accent: item.isAvailable,
                            radius: 12,
                            padding: const EdgeInsets.all(7),
                            child: Icon(Icons.add_rounded,
                                color: item.isAvailable
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: AppColors.crema,
        child: const Icon(Icons.local_cafe_rounded,
            color: AppColors.amber, size: 36),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.crema),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.crema,
        child: const Icon(Icons.local_cafe_rounded,
            color: AppColors.amber, size: 36),
      ),
    );
  }
}
