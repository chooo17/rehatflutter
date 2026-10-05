import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/app_lifecycle.dart';
import '../../../shared/models/order_model.dart';
import '../data/printer_bridge.dart';
import '../data/receipt_template.dart';

class PrinterState {
  const PrinterState({
    this.supported = false,
    this.connected = false,
    this.deviceName,
    this.address,
    this.busy = false,
  });

  final bool supported;
  final bool connected;
  final String? deviceName;
  final String? address;
  final bool busy;

  PrinterState copyWith({
    bool? connected,
    String? deviceName,
    String? address,
    bool? busy,
  }) =>
      PrinterState(
        supported: supported,
        connected: connected ?? this.connected,
        deviceName: deviceName ?? this.deviceName,
        address: address ?? this.address,
        busy: busy ?? this.busy,
      );
}

/// Jembatan printer sebagai provider agar bisa diganti saat pengujian.
final printerBridgeProvider =
    Provider<PrinterBridge>((ref) => createPrinterBridge());

class PrinterController extends Notifier<PrinterState> {
  static const _kAddr = 'printer_address';
  static const _kName = 'printer_name';
  final FlutterSecureStorage _storage = appSecureStorage;
  late final PrinterBridge _bridge;

  @override
  PrinterState build() {
    _bridge = ref.watch(printerBridgeProvider);
    if (_bridge.supported) {
      _loadSaved();
      // Koneksi Bluetooth bisa putus diam-diam saat app di background (printer
      // dimatikan, keluar jangkauan, HP dikunci). Tanpa pemeriksaan ulang saat
      // kembali ke depan, layar pengaturan terus menampilkan "Tersambung" yang
      // salah dan tombol "Tes Cetak" bisa aktif padahal printer sudah lepas.
      ref.listen<bool>(appForegroundProvider, (prev, next) {
        if (next && prev != true) refreshConnection();
      });
    }
    return PrinterState(supported: _bridge.supported);
  }

  Future<void> _loadSaved() async {
    // Penyimpanan aman bisa gagal (plugin belum siap / platform tanpa
    // dukungan). Jangan sampai jadi galat asinkron yang tak tertangani.
    String? addr, name;
    try {
      addr = await _storage.read(key: _kAddr);
      name = await _storage.read(key: _kName);
    } catch (_) {
      return;
    }
    if (addr != null) {
      final conn = await _bridge.connected();
      state = state.copyWith(address: addr, deviceName: name, connected: conn);
    }
  }

  /// Daftar printer ter-pairing (minta izin dulu).
  Future<List<BtPrinter>> listPaired() async {
    await _bridge.ensurePermissions();
    return _bridge.paired();
  }

  /// Sambungkan & simpan sebagai printer default.
  Future<bool> connectTo(BtPrinter p) async {
    state = state.copyWith(busy: true);
    final ok = await _bridge.connect(p.address);
    if (ok) {
      await _storage.write(key: _kAddr, value: p.address);
      await _storage.write(key: _kName, value: p.name);
    }
    state = state.copyWith(
      busy: false,
      connected: ok,
      address: ok ? p.address : null,
      deviceName: ok ? p.name : null,
    );
    return ok;
  }

  Future<void> disconnect() async {
    await _bridge.disconnect();
    state = state.copyWith(connected: false);
  }

  /// Memeriksa ulang status koneksi ke printer. Dipanggil saat aplikasi kembali
  /// ke depan dan saat layar pengaturan printer dibuka.
  Future<void> refreshConnection() async {
    if (!_bridge.supported) return;
    state = state.copyWith(connected: await _bridge.connected());
  }

  Future<bool> _ensureConnected() async {
    if (await _bridge.connected()) return true;
    final addr = state.address ?? await _storage.read(key: _kAddr);
    if (addr == null) return false;
    return _bridge.connect(addr);
  }

  final Set<String> _autoPrinted = {};

  /// Auto-cetak struk SEKALI per pesanan (dedupe), HANYA di perangkat yang
  /// printer-nya tersambung. Dipanggil begitu pesanan terdeteksi lunas.
  Future<void> autoPrintOnce(OrderModel order) async {
    if (!_bridge.supported || _autoPrinted.contains(order.id)) return;
    if (!await _bridge.connected()) return; // hanya perangkat kasir berprinter
    final ok = await printOrder(order);
    if (ok) _autoPrinted.add(order.id);
  }

  /// Cetak struk pesanan memakai template tersimpan. `false` bila gagal.
  Future<bool> printOrder(OrderModel order) async {
    if (!_bridge.supported) return false;
    state = state.copyWith(busy: true);
    try {
      if (!await _ensureConnected()) {
        state = state.copyWith(busy: false, connected: false);
        return false;
      }
      final template = await ref.read(receiptTemplateProvider.future);
      final logo = await ref.read(receiptLogoProvider.future);
      final ok = await _bridge.printReceipt(renderReceipt(template, order),
          logoBytes: logo);
      state = state.copyWith(busy: false, connected: true);
      return ok;
    } catch (_) {
      state = state.copyWith(busy: false);
      return false;
    }
  }

  /// Cetak teks bebas (untuk tes cetak dari pengaturan).
  Future<bool> printRaw(String text) async {
    if (!_bridge.supported) return false;
    state = state.copyWith(busy: true);
    try {
      if (!await _ensureConnected()) {
        state = state.copyWith(busy: false, connected: false);
        return false;
      }
      final logo = await ref.read(receiptLogoProvider.future);
      final ok = await _bridge.printReceipt(text, logoBytes: logo);
      state = state.copyWith(busy: false, connected: true);
      return ok;
    } catch (_) {
      state = state.copyWith(busy: false);
      return false;
    }
  }
}

final printerControllerProvider =
    NotifierProvider<PrinterController, PrinterState>(PrinterController.new);
