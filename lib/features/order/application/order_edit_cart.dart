import '../data/order_repository.dart';

/// Satu baris item saat mengedit pesanan tersimpan.
class EditLine {
  EditLine({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.optionSummary = '',
    this.customization = const {},
  });

  final String menuItemId;
  final String name;
  final int unitPrice;
  int quantity;

  /// Ringkasan opsi (mis. "Large • Panas") — kosong untuk item baru tanpa opsi.
  final String optionSummary;
  final Map<String, dynamic> customization;

  int get subtotal => unitPrice * quantity;
}

/// Keranjang kerja saat mengedit pesanan tersimpan. Logika murni (tanpa UI /
/// jaringan) supaya bisa di-unit-test: tambah/dedup, +/- jumlah, hapus, total.
class OrderEditCart {
  OrderEditCart(this.lines);

  final List<EditLine> lines;

  int get total => lines.fold(0, (s, e) => s + e.subtotal);
  bool get isEmpty => lines.isEmpty;

  void inc(EditLine line) => line.quantity++;

  /// Kurangi jumlah; saat mencapai 0 baris dihapus.
  void dec(EditLine line) {
    if (line.quantity > 1) {
      line.quantity--;
    } else {
      lines.remove(line);
    }
  }

  void remove(EditLine line) => lines.remove(line);

  /// Tambah item dari menu. Item sama TANPA opsi → naikkan jumlah baris yang ada
  /// (hindari baris duplikat); selain itu tambah baris baru qty 1.
  void addMenu({
    required String menuItemId,
    required String name,
    required int unitPrice,
  }) {
    final existing = lines.where(
        (e) => e.menuItemId == menuItemId && e.optionSummary.isEmpty);
    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      lines.add(EditLine(
          menuItemId: menuItemId,
          name: name,
          unitPrice: unitPrice,
          quantity: 1));
    }
  }

  /// Konversi ke payload API.
  List<EditOrderItem> toItems() => [
        for (final l in lines)
          EditOrderItem(
              menuItemId: l.menuItemId,
              quantity: l.quantity,
              customization: l.customization),
      ];
}
