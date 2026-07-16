import 'printer_bridge_stub.dart'
    if (dart.library.io) 'printer_bridge_mobile.dart' as impl;
import 'printer_types.dart';

export 'printer_types.dart';

/// Membuat implementasi printer sesuai platform: Android nyata, lainnya no-op.
PrinterBridge createPrinterBridge() => impl.createBridge();
