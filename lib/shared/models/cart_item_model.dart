import '../../core/utils/customization_labels.dart';
import 'menu_item_model.dart';

/// Satu baris di keranjang: item menu + kustomisasi (ukuran/gula/suhu) + jumlah.
///
/// Catatan: backend menghitung harga dari `price × quantity` — ukuran TIDAK
/// menambah harga. Jadi `unitPrice` selalu harga dasar item.
class CartItemModel {
  const CartItemModel({
    required this.item,
    this.size,
    this.sugarLevel,
    this.temperature,
    this.quantity = 1,
  });

  final MenuItemModel item;

  /// 'small' | 'regular' | 'large' (atau null bila item tak punya opsi ukuran).
  final String? size;

  /// 0–100 (atau null).
  final int? sugarLevel;

  /// 'hot' | 'iced' (atau null).
  final String? temperature;

  final int quantity;

  /// Kunci unik per kombinasi item + kustomisasi (untuk menggabungkan baris).
  String get lineId => '${item.id}_${size ?? ''}_${sugarLevel ?? ''}_${temperature ?? ''}';

  /// Harga satuan = harga dasar item (tanpa biaya tambahan ukuran).
  int get unitPrice => item.price;

  /// Subtotal baris ini.
  int get subtotal => unitPrice * quantity;

  /// Ringkasan kustomisasi untuk ditampilkan, mis. "Reguler · Dingin · Gula 50%".
  String get customizationSummary => CustomizationLabels.summary(
        size: size,
        sugarLevel: sugarLevel,
        temperature: temperature,
      );

  /// Payload `customization` untuk POST /orders.
  Map<String, dynamic> get customizationJson => {
        if (size != null) 'size': size,
        if (sugarLevel != null) 'sugar_level': sugarLevel,
        if (temperature != null) 'temperature': temperature,
      };

  CartItemModel copyWith({int? quantity}) {
    return CartItemModel(
      item: item,
      size: size,
      sugarLevel: sugarLevel,
      temperature: temperature,
      quantity: quantity ?? this.quantity,
    );
  }
}
