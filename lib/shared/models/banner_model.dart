/// Banner promo untuk beranda (dari `GET /banners`).
class BannerModel {
  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),
      isActive: (json['is_active'] ?? json['isActive'] ?? true) == true,
      sortOrder: json['sort_order'] is num
          ? (json['sort_order'] as num).toInt()
          : int.tryParse((json['sort_order'] ?? '0').toString()) ?? 0,
    );
  }
}
