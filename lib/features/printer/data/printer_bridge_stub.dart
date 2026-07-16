import 'printer_types.dart';

/// Implementasi kosong untuk web / platform tanpa Bluetooth thermal.
class _StubBridge implements PrinterBridge {
  @override
  bool get supported => false;

  @override
  Future<bool> ensurePermissions() async => false;

  @override
  Future<List<BtPrinter>> paired() async => const [];

  @override
  Future<bool> connect(String address) async => false;

  @override
  Future<bool> connected() async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> printReceipt(String text, {List<int>? logoBytes}) async => false;
}

PrinterBridge createBridge() => _StubBridge();
