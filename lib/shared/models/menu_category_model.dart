/// Kategori menu (dari tabel `menu_categories` backend).
class MenuCategory {
  const MenuCategory({required this.id, required this.name, this.slug = ''});

  final String id;
  final String name;
  final String slug;

  /// Kategori semu "Semua" (tanpa filter) — id kosong.
  static const MenuCategory all = MenuCategory(id: '', name: 'Semua');

  bool get isAll => id.isEmpty;

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
    );
  }
}
