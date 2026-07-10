import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/menu_item_model.dart';
import '../../../shared/models/order_model.dart';
import '../../menu/application/cart_controller.dart';
import '../../menu/data/menu_repository.dart';
import '../data/order_repository.dart';

/// Ringkasan hasil "Pesan Lagi".
class ReorderResult {
  const ReorderResult({required this.added, required this.skipped});

  /// Jumlah baris item yang berhasil ditambahkan ke keranjang.
  final int added;

  /// Nama item yang dilewati (tidak tersedia / sudah dihapus dari menu).
  final List<String> skipped;

  bool get hasAdded => added > 0;
  bool get hasSkipped => skipped.isNotEmpty;
}

/// Mengisi ulang keranjang dari sebuah pesanan lama.
///
/// Untuk tiap item, harga & ketersediaan diambil dari data menu terkini
/// (bukan snapshot lama). Item yang habis / hilang dilewati dan dilaporkan.
final reorderServiceProvider = Provider<ReorderService>((ref) {
  return ReorderService(ref);
});

class ReorderService {
  ReorderService(this._ref);
  final Ref _ref;

  Future<ReorderResult> addOrderToCart(OrderModel order) async {
    final menuRepo = _ref.read(menuRepositoryProvider);
    final cart = _ref.read(cartControllerProvider.notifier);

    // Kartu riwayat hanya membawa ringkasan — ambil detail penuh bila perlu.
    var source = order;
    if (source.items.isEmpty && source.id.isNotEmpty) {
      source = await _ref.read(orderRepositoryProvider).fetchDetail(order.id);
    }

    var added = 0;
    final skipped = <String>[];

    for (final line in source.items) {
      MenuItemModel? current;
      if (line.menuItemId.isNotEmpty) {
        try {
          current = await menuRepo.fetchDetail(line.menuItemId);
        } catch (_) {
          current = null; // 404 / error → dianggap tidak tersedia.
        }
      }

      if (current == null || !current.isAvailable) {
        skipped.add(line.name.isNotEmpty ? line.name : 'Item');
        continue;
      }

      cart.add(
        current,
        size: line.size,
        sugarLevel: line.sugarLevel,
        temperature: line.temperature,
        quantity: line.quantity,
      );
      added++;
    }

    return ReorderResult(added: added, skipped: skipped);
  }
}
