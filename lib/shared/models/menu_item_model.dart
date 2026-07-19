/// Opsi kustomisasi item menu (dari kolom `options` backend).
class MenuOptions {
  const MenuOptions({
    this.sizes = const [],
    this.sugarLevels = const [],
    this.temperatures = const [],
  });

  /// mis. ['small', 'regular', 'large'].
  final List<String> sizes;

  /// mis. [0, 25, 50, 75, 100].
  final List<int> sugarLevels;

  /// mis. ['hot', 'iced'].
  final List<String> temperatures;

  bool get hasAny =>
      sizes.isNotEmpty || sugarLevels.isNotEmpty || temperatures.isNotEmpty;

  factory MenuOptions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MenuOptions();
    List<String> strs(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    List<int> ints(dynamic v) => v is List
        ? v
            .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()) ?? 0)
            .toList()
        : const [];
    return MenuOptions(
      sizes: strs(json['sizes']),
      sugarLevels: ints(json['sugar_levels']),
      temperatures: strs(json['temperatures']),
    );
  }
}

/// Model satu item menu (minuman / makanan).
class MenuItemModel {
  const MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0,
    this.description = '',
    this.imageUrl,
    this.category = '',
    this.isFeatured = false,
    this.isAvailable = true,
    this.rating,
    this.options = const MenuOptions(),
  });

  final String id;
  final String name;
  final String description;

  /// Harga jual dalam Rupiah (bilangan bulat, tanpa desimal).
  final int price;

  /// Harga modal / HPP dalam Rupiah (untuk hitung margin). 0 = belum diisi.
  final int costPrice;

  /// Margin kotor per unit (%). Null bila harga jual 0.
  int? get marginPct =>
      price > 0 ? (((price - costPrice) / price) * 100).round() : null;

  final String? imageUrl;
  final String category;
  final bool isFeatured;
  final bool isAvailable;

  /// Rating 0–5 (opsional).
  final double? rating;

  /// Opsi kustomisasi (ukuran, gula, suhu).
  final MenuOptions options;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _asInt(json['price']),
      costPrice: _asInt(json['cost_price'] ?? json['costPrice']),
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      // Backend mengirim kategori sebagai objek: `category` (list/detail) atau
      // `menu_categories` (featured). Bisa juga string biasa.
      category: _categoryName(
          json['category'] ?? json['menu_categories'] ?? json['category_name']),
      isFeatured: (json['is_featured'] ?? json['isFeatured'] ?? false) == true,
      isAvailable: (json['is_available'] ?? json['isAvailable'] ?? true) == true,
      rating: _asDouble(json['avg_rating'] ?? json['rating']),
      options: MenuOptions.fromJson(
          json['options'] is Map ? Map<String, dynamic>.from(json['options']) : null),
    );
  }

  static String _categoryName(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) return (v['name'] ?? v['title'] ?? '').toString();
    return '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'image_url': imageUrl,
        'category': category,
        'is_featured': isFeatured,
        'is_available': isAvailable,
        'rating': rating,
      };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
