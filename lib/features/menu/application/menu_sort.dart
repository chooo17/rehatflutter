import 'package:flutter/material.dart';

/// Opsi pengurutan katalog menu (nilai `apiValue` sesuai backend).
enum MenuSort {
  recommended('sort_order', 'Rekomendasi', Icons.auto_awesome_rounded),
  priceAsc('price_asc', 'Harga termurah', Icons.arrow_upward_rounded),
  priceDesc('price_desc', 'Harga termahal', Icons.arrow_downward_rounded),
  rating('rating', 'Rating tertinggi', Icons.star_rounded);

  const MenuSort(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;
}
