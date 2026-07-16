import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/menu_item_model.dart';
import '../../../../shared/widgets/neu.dart';

/// Kartu menu unggulan (dipakai di daftar horizontal beranda).
class FeaturedMenuCard extends StatelessWidget {
  const FeaturedMenuCard({super.key, required this.item, this.onTap});

  final MenuItemModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: NeuCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: AspectRatio(
                aspectRatio: 1.25,
                child: _Image(url: item.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium,
                  ),
                  if (item.category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Formatters.rupiah(item.price),
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.amberDark),
                        ),
                      ),
                      const NeuButton(
                        accent: true,
                        radius: 12,
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.add_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
      memCacheWidth: 500,
      placeholder: (_, __) => Container(color: AppColors.crema),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.crema,
        child: const Icon(Icons.local_cafe_rounded,
            color: AppColors.amber, size: 36),
      ),
    );
  }
}
