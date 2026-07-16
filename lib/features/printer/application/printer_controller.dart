import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

class PrinterController extends Notifier<PrinterState> {
  static const _kAddr = 'printer_address';
  static const _kName = 'printer_name';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final PrinterBridge _bridge;

  @override
  PrinterState build() {
    _bridge = createPrinterBridge();
    if (_bridge.supported) _loadSaved();
    return PrinterState(supported: _bridge.supported);
  }

  Future<void> _loadSaved() async {
    final addr = await _storage.read(key: _kAddr);
    final name = await _storage.read(key: _kName);
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

  Future<void> refreshConnection() async {
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
