import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;

import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';

/// Lebar karakter kertas 58mm (± 32 kolom).
const int _paperCols = 32;

/// Template struk bawaan. Placeholder didukung: {antrian} {tanggal} {nama}
/// {metode} {items} {total}. Baris diawali '#' = judul tebal besar (tengah),
/// '@' = rata tengah normal.
const String defaultReceiptTemplate = '''
#REHAT COFFEEHOUSE
@Jl. Kopi No. 1, Kota Anda
@--------------------------------
No. Antrian : {antrian}
Tanggal     : {tanggal}
Pelanggan   : {nama}
Metode      : {metode}
--------------------------------
{items}
--------------------------------
TOTAL       : {total}
@--------------------------------
@Terima kasih & sampai jumpa!''';

String _methodLabel(String? m) {
  switch ((m ?? '').toLowerCase()) {
    case 'qris':
      return 'QRIS';
    case 'cash':
      return 'Tunai';
    case '':
      return '-';
    default:
      return m!.toUpperCase();
  }
}

/// Baris dua-kolom (kiri | kanan) selebar [_paperCols].
String _row(String left, String right) {
  final maxLeft = _paperCols - right.length - 1;
  var l = left;
  if (maxLeft > 0 && l.length > maxLeft) l = l.substring(0, maxLeft);
  final pad = _paperCols - l.length - right.length;
  return l + (' ' * (pad < 1 ? 1 : pad)) + right;
}

/// Render template + data pesanan menjadi teks struk siap cetak.
String renderReceipt(String template, OrderModel order) {
  final itemLines = order.items.isEmpty
      ? '-'
      : order.items
          .map((i) => _row('${i.quantity}x ${i.name}',
              Formatters.rupiah(i.subtotal).replaceAll('Rp', '').trim()))
          .join('\n');
  var nama = order.customerName.isEmpty ? 'Pelanggan' : order.customerName;
  // Nomor meja (QR meja) selalu tampil di struk — ditempel ke nama agar muncul
  // walau template kustom belum punya placeholder khusus.
  if (order.tableNumber != null) nama = '$nama (Meja ${order.tableNumber})';
  return template
      .replaceAll('{antrian}', order.queueNumber.isEmpty ? '-' : order.queueNumber)
      .replaceAll('{tanggal}', Formatters.tanggalJam(order.createdAt))
      .replaceAll('{meja}', order.tableNumber ?? '-')
      .replaceAll('{nama}', nama)
      .replaceAll('{metode}', _methodLabel(order.paymentMethod))
      .replaceAll('{items}', itemLines)
      .replaceAll('{total}', Formatters.rupiah(order.total));
}

/// Penyimpanan template struk (lokal per-perangkat, dapat diedit admin).
class ReceiptTemplateController extends AsyncNotifier<String> {
  static const _key = 'receipt_template_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String> build() async {
    try {
      final saved = await _storage.read(key: _key);
      return (saved == null || saved.isEmpty) ? defaultReceiptTemplate : saved;
    } catch (_) {
      return defaultReceiptTemplate;
    }
  }

  Future<void> save(String template) async {
    final t = template.trim().isEmpty ? defaultReceiptTemplate : template;
    await _storage.write(key: _key, value: t);
    state = AsyncData(t);
  }

  Future<void> resetToDefault() async {
    await _storage.delete(key: _key);
    state = const AsyncData(defaultReceiptTemplate);
  }
}

final receiptTemplateProvider =
    AsyncNotifierProvider<ReceiptTemplateController, String>(
        ReceiptTemplateController.new);

/// Logo struk (lokal per-perangkat). Disimpan sebagai PNG base64 yang SUDAH
/// di-resize ke lebar printer 58mm (~360 dot) + grayscale, siap dicetak di
/// tengah paling atas nota. `null` = tanpa logo.
class ReceiptLogoController extends AsyncNotifier<Uint8List?> {
  static const _key = 'receipt_logo_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<Uint8List?> build() async {
    try {
      final b64 = await _storage.read(key: _key);
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Simpan logo dari gambar mentah (hasil pilih dari galeri).
  Future<void> save(List<int> rawBytes) async {
    final decoded = img.decodeImage(Uint8List.fromList(rawBytes));
    if (decoded == null) {
      throw Exception('Format gambar tidak didukung.');
    }
    // Resize ke lebar printer (maks 360 dot) + grayscale (thermal monokrom).
    final resized = decoded.width > 360
        ? img.copyResize(decoded, width: 360)
        : decoded;
    final png = img.encodePng(img.grayscale(resized));
    await _storage.write(key: _key, value: base64Encode(png));
    state = AsyncData(Uint8List.fromList(png));
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    state = const AsyncData(null);
  }
}

final receiptLogoProvider =
    AsyncNotifierProvider<ReceiptLogoController, Uint8List?>(
        ReceiptLogoController.new);
