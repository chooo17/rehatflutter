import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/menu_item_model.dart';

/// Mengelola isi keranjang belanja (in-memory selama sesi).
class CartController extends Notifier<List<CartItemModel>> {
  @override
  List<CartItemModel> build() => const [];

  /// Menambah item; jika baris (item+kustomisasi) sudah ada, jumlahnya ditambah.
  void add(
    MenuItemModel item, {
    String? size,
    int? sugarLevel,
    String? temperature,
    int quantity = 1,
  }) {
    final newItem = CartItemModel(
      item: item,
      size: size,
      sugarLevel: sugarLevel,
      temperature: temperature,
      quantity: quantity,
    );
    final index = state.indexWhere((e) => e.lineId == newItem.lineId);
    if (index >= 0) {
      final existing = state[index];
      final updated = existing.copyWith(quantity: existing.quantity + quantity);
      state = [...state]..[index] = updated;
    } else {
      state = [...state, newItem];
    }
  }

  void setQuantity(String lineId, int quantity) {
    if (quantity <= 0) {
      remove(lineId);
      return;
    }
    state = [
      for (final e in state)
        if (e.lineId == lineId) e.copyWith(quantity: quantity) else e,
    ];
  }

  void increment(String lineId) {
    final item = _find(lineId);
    if (item != null) setQuantity(lineId, item.quantity + 1);
  }

  void decrement(String lineId) {
    final item = _find(lineId);
    if (item != null) setQuantity(lineId, item.quantity - 1);
  }

  void remove(String lineId) {
    state = state.where((e) => e.lineId != lineId).toList();
  }

  void clear() => state = const [];

  CartItemModel? _find(String lineId) {
    for (final e in state) {
      if (e.lineId == lineId) return e;
    }
    return null;
  }
}

final cartControllerProvider =
    NotifierProvider<CartController, List<CartItemModel>>(CartController.new);

/// Total jumlah unit di keranjang (untuk badge).
final cartCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartControllerProvider);
  return items.fold(0, (sum, e) => sum + e.quantity);
});

/// Total harga keranjang (Rupiah).
final cartTotalProvider = Provider<int>((ref) {
  final items = ref.watch(cartControllerProvider);
  return items.fold(0, (sum, e) => sum + e.subtotal);
});
