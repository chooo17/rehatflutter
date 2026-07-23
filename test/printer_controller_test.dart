import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/utils/app_lifecycle.dart';
import 'package:rehat_app/features/printer/application/printer_controller.dart';
import 'package:rehat_app/features/printer/data/printer_bridge.dart';

/// Bridge palsu: menghitung pemeriksaan koneksi dan bisa "diputus" sewaktu-waktu
/// untuk meniru printer yang mati / keluar jangkauan.
class _FakePrinterBridge implements PrinterBridge {
  _FakePrinterBridge({this.supported = true, this.isConnected = true});

  @override
  final bool supported;

  bool isConnected;
  int connectedCalls = 0;

  @override
  Future<bool> connected() async {
    connectedCalls++;
    return isConnected;
  }

  @override
  Future<bool> connect(String address) async => isConnected = true;

  @override
  Future<void> disconnect() async => isConnected = false;

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<List<BtPrinter>> paired() async => const [];

  @override
  Future<bool> printReceipt(String text, {List<int>? logoBytes}) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePrinterBridge bridge;
  late ProviderContainer container;

  void build({bool supported = true, bool connected = true}) {
    bridge = _FakePrinterBridge(supported: supported, isConnected: connected);
    container = ProviderContainer(
      overrides: [printerBridgeProvider.overrideWithValue(bridge)],
    );
  }

  tearDown(() => container.dispose());

  PrinterController printer() =>
      container.read(printerControllerProvider.notifier);

  /// Menunggu satu putaran event loop agar efek asinkron sempat jalan.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Menegakkan status awal "tersambung" lewat jalur nyata. Tanpa ini status
  /// awal selalu `false` (penyimpanan aman tak tersedia saat pengujian),
  /// sehingga pengujian yang mengharapkan `false` lulus secara semu.
  Future<void> establishConnected() async {
    await printer().refreshConnection();
    expect(container.read(printerControllerProvider).connected, isTrue,
        reason: 'prasyarat: harus tersambung dulu');
  }

  test('refreshConnection memperbarui status tersambung', () async {
    build(connected: true);
    printer(); // inisialisasi
    await settle();
    await establishConnected();

    bridge.isConnected = false; // printer dimatikan / keluar jangkauan
    await printer().refreshConnection();

    expect(container.read(printerControllerProvider).connected, isFalse);
  });

  test('status "tersambung" pulih setelah printer kembali', () async {
    build(connected: false);
    printer();
    await settle();

    bridge.isConnected = true;
    await printer().refreshConnection();

    expect(container.read(printerControllerProvider).connected, isTrue);
  });

  test('kembali ke depan (resumed) memeriksa ulang koneksi printer', () async {
    build();
    printer();
    await settle();
    final before = bridge.connectedCalls;

    // Ke background lalu kembali — persis kasus kasir yang mengunci HP.
    container.read(appForegroundProvider.notifier).state = false;
    await settle();
    container.read(appForegroundProvider.notifier).state = true;
    await settle();

    expect(bridge.connectedCalls, greaterThan(before));
  });

  test('status ikut berubah saat printer mati selama di background', () async {
    build(connected: true);
    printer();
    await settle();
    await establishConnected();

    container.read(appForegroundProvider.notifier).state = false;
    bridge.isConnected = false; // printer mati saat app di background
    await settle();
    container.read(appForegroundProvider.notifier).state = true;
    await settle();

    expect(container.read(printerControllerProvider).connected, isFalse);
  });

  test('masuk ke background TIDAK memeriksa koneksi', () async {
    build();
    printer();
    await settle();
    final before = bridge.connectedCalls;

    container.read(appForegroundProvider.notifier).state = false;
    await settle();

    expect(bridge.connectedCalls, before);
  });

  test('platform tanpa dukungan printer tidak memeriksa apa pun', () async {
    build(supported: false);
    printer();
    await settle();

    container.read(appForegroundProvider.notifier).state = false;
    await settle();
    container.read(appForegroundProvider.notifier).state = true;
    await settle();
    await printer().refreshConnection();

    expect(bridge.connectedCalls, 0);
    expect(container.read(printerControllerProvider).connected, isFalse);
  });
}
