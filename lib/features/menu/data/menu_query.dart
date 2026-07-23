import '../../../shared/models/menu_item_model.dart';
import '../application/menu_sort.dart';

/// Menyaring & mengurutkan katalog menu DI SISI KLIEN.
///
/// Menirukan perilaku `GET /menu/items` (lihat `src/routes/index.js`) supaya
/// mengganti kategori / mengetik / mengubah urutan tidak perlu menembak
/// backend lagi — katalog cukup diambil SEKALI lalu diolah di perangkat.
///
/// Satu perbedaan yang DISENGAJA: pada urutan rating, item tanpa rating
/// ditaruh di BELAKANG. Postgres `ORDER BY ... DESC` menaruh NULL di depan,
/// yang membuat menu tanpa ulasan justru muncul teratas.
List<MenuItemModel> applyMenuQuery(
  List<MenuItemModel> items, {
  String categoryId = '',
  String query = '',
  MenuSort sort = MenuSort.recommended,
}) {
  final q = query.trim().toLowerCase();

  final filtered = [
    for (final item in items)
      if ((categoryId.isEmpty || item.categoryId == categoryId) &&
          (q.isEmpty ||
              item.name.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q)))
        item,
  ];

  switch (sort) {
    // Urutan dari backend SUDAH `sort_order` menaik — pertahankan apa adanya.
    case MenuSort.recommended:
      break;
    case MenuSort.priceAsc:
      filtered.sort((a, b) => a.price.compareTo(b.price));
    case MenuSort.priceDesc:
      filtered.sort((a, b) => b.price.compareTo(a.price));
    case MenuSort.rating:
      filtered.sort((a, b) {
        final ra = a.rating, rb = b.rating;
        if (ra == null && rb == null) return 0;
        if (ra == null) return 1;
        if (rb == null) return -1;
        return rb.compareTo(ra);
      });
  }

  return filtered;
}
