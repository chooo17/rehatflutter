import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_types.dart';

/// Implementasi nyata untuk Android memakai print_bluetooth_thermal + ESC/POS.
class _MobileBridge implements PrinterBridge {
  @override
  bool get supported => true;

  @override
  Future<bool> ensurePermissions() async {
    // Android 12+ butuh izin runtime BLUETOOTH_CONNECT/SCAN.
    final res = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    // Perangkat < Android 12 mengembalikan granted otomatis.
    return res[Permission.bluetoothConnect]?.isGranted ?? true;
  }

  @override
  Future<List<BtPrinter>> paired() async {
    try {
      final list = await PrintBluetoothThermal.pairedBluetooths;
      return list
          .map((b) => BtPrinter(b.name, b.macAdress))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> connect(String address) async {
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: address);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> connected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  @override
  Future<bool> printReceipt(String text, {List<int>? logoBytes}) async {
    try {
      if (!await connected()) return false;
      final profile = await CapabilityProfile.load();
      final gen = Generator(PaperSize.mm58, profile);
      final bytes = <int>[];
      bytes.addAll(gen.reset());
      // Logo di TENGAH paling atas (bila ada).
      if (logoBytes != null && logoBytes.isNotEmpty) {
        final logo = img.decodeImage(Uint8List.fromList(logoBytes));
        if (logo != null) {
          bytes.addAll(gen.image(logo, align: PosAlign.center));
          bytes.addAll(gen.feed(1));
        }
      }
      for (final line in text.split('\n')) {
        // Baris diawali '#' → tebal & rata tengah (mis. nama toko / judul).
        if (line.startsWith('#')) {
          bytes.addAll(gen.text(line.substring(1).trim(),
              styles: const PosStyles(
                  align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)));
        } else if (line.startsWith('@')) {
          // '@' → rata tengah normal (mis. alamat / footer).
          bytes.addAll(gen.text(line.substring(1).trim(),
              styles: const PosStyles(align: PosAlign.center)));
        } else {
          bytes.addAll(gen.text(line, styles: const PosStyles(align: PosAlign.left)));
        }
      }
      bytes.addAll(gen.feed(2));
      bytes.addAll(gen.cut());
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }
}

PrinterBridge createBridge() => _MobileBridge();
