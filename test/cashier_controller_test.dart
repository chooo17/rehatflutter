import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/api_exception.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/menu/application/cart_controller.dart';
import 'package:rehat_app/features/menu/application/cashier_controller.dart';
import 'package:rehat_app/features/order/data/order_repository.dart';
import 'package:rehat_app/features/wallet/data/wallet_repository.dart';
import 'package:rehat_app/shared/models/cart_item_model.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';
import 'package:rehat_app/shared/models/order_model.dart';

/// PENGUJIAN KARAKTERISASI jalur uang KASIR.
///
/// Kembaran dari `checkout_controller_test.dart` untuk sisi kasir. Fokus utama:
/// jalur bayar-Saldo tidak boleh melahirkan pesanan kedua saat potong saldo
/// admin gagal (mis. saldo kurang) lalu kasir menekan bayar lagi.

const _result = CheckoutResult(
  orderId: 'ord-k1',
  queueNumber: 'A-3',
  subtotal: 30000,
  discountAmount: 0,
  total: 30000,
  paymentMethod: PaymentMethod.cash,
);

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository() : super(client: DioClient(storage: SecureStorage()));

  int createCashierOrderCalls = 0;
  String? lastCustomerName;
  bool? lastPayNow;
  PaymentMethod? lastPaymentMethod;
  OrderType? lastOrderType;
  Object? throwOnCreate;

  @override
  Future<CheckoutResult> createCashierOrder({
    required List<CartItemModel> items,
    OrderType orderType = OrderType.dineIn,
    String? notes,
    String? customerName,
    bool payNow = true,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) async {
    createCashierOrderCalls++;
    lastCustomerName = customerName;
    lastPayNow = payNow;
    lastPaymentMethod = paymentMethod;
    lastOrderType = orderType;
    if (throwOnCreate != null) throw throwOnCreate!;
    return _result;
  }

  // Invalidasi provider admin menembak repo ini; beri jawaban kosong supaya
  // tidak menyentuh Dio sungguhan.
  @override
  Future<List<OrderModel>> fetchAllOrders(
          {String? status, String? date, int page = 1, int limit = 30}) async =>
      const [];
}

class _FakeWalletRepository extends WalletRepository {
  _FakeWalletRepository() : super(client: DioClient(storage: SecureStorage()));

  final List<String> paidOrderIds = [];
  Object? throwOnPay;

  @override
  Future<void> adminPayWithBalance(String orderId) async {
    paidOrderIds.add(orderId);
    if (throwOnPay != null) throw throwOnPay!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeOrderRepository orders;
  late _FakeWalletRepository wallet;
  late ProviderContainer container;

  void build() {
    orders = _FakeOrderRepository();
    wallet = _FakeWalletRepository();
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(orders),
        walletRepositoryProvider.overrideWithValue(wallet),
      ],
    );
  }

  tearDown(() => container.dispose());

  CashierController cashier() =>
      container.read(cashierControllerProvider.notifier);
  CashierState state() => container.read(cashierControllerProvider);
  CartController cart() => container.read(cartControllerProvider.notifier);

  void fillCart() => cart()
      .add(const MenuItemModel(id: 'm1', name: 'Kopi', price: 30000),
          quantity: 1);

  Future<CheckoutResult?> submit(CashierPayMode mode, {String name = 'Budi'}) =>
      cashier().submit(
          mode: mode, customerName: name, orderType: OrderType.dineIn);

  group('penjagaan dasar', () {
    test('keranjang kosong ditolak tanpa memanggil backend', () async {
      build();

      final result = await submit(CashierPayMode.cash);

      expect(result, isNull);
      expect(state().errorMessage, 'Keranjang kosong.');
      expect(orders.createCashierOrderCalls, 0);
    });
  });

  group('jalur sukses', () {
    test('Tunai memakai payNow=true & mengosongkan keranjang', () async {
      build();
      fillCart();

      final result = await submit(CashierPayMode.cash);

      expect(result?.orderId, 'ord-k1');
      expect(orders.createCashierOrderCalls, 1);
      expect(orders.lastPayNow, isTrue);
      expect(orders.lastPaymentMethod, PaymentMethod.cash);
      expect(orders.lastCustomerName, 'Budi');
      expect(container.read(cartControllerProvider), isEmpty);
    });

    test('QRIS memakai payNow=false & metode qris', () async {
      build();
      fillCart();

      await submit(CashierPayMode.qris);

      expect(orders.lastPayNow, isFalse);
      expect(orders.lastPaymentMethod, PaymentMethod.qris);
      expect(wallet.paidOrderIds, isEmpty);
    });

    test('Simpan (bayar nanti) memakai payNow=false, tanpa potong saldo',
        () async {
      build();
      fillCart();

      await submit(CashierPayMode.save);

      expect(orders.lastPayNow, isFalse);
      expect(wallet.paidOrderIds, isEmpty);
    });

    test('Saldo memotong saldo admin untuk pesanan baru', () async {
      build();
      fillCart();

      await submit(CashierPayMode.balance);

      expect(orders.createCashierOrderCalls, 1);
      expect(wallet.paidOrderIds, ['ord-k1']);
      expect(container.read(cartControllerProvider), isEmpty);
    });
  });

  group('kegagalan', () {
    test('ApiException saat membuat pesanan menampilkan pesan server', () async {
      build();
      fillCart();
      orders.throwOnCreate = ApiException('Menu habis.', code: 'X');

      final result = await submit(CashierPayMode.cash);

      expect(result, isNull);
      expect(state().errorMessage, 'Menu habis.');
      expect(container.read(cartControllerProvider), isNotEmpty);
    });

    test('saldo kurang: pesanan dibuat tapi keranjang tetap terisi', () async {
      build();
      fillCart();
      wallet.throwOnPay = ApiException('Saldo admin kurang.', code: 'INSUFF');

      final result = await submit(CashierPayMode.balance);

      expect(result, isNull);
      expect(state().errorMessage, 'Saldo admin kurang.');
      expect(orders.createCashierOrderCalls, 1); // pesanan TERLANJUR dibuat
      expect(container.read(cartControllerProvider), isNotEmpty);
    });
  });

  group('ulang bayar Saldo setelah gagal (anti pesanan ganda)', () {
    Future<void> failedBalanceAttempt() async {
      fillCart();
      wallet.throwOnPay = ApiException('Saldo admin kurang.', code: 'INSUFF');
      await submit(CashierPayMode.balance);
    }

    test('menekan Bayar Saldo lagi TIDAK membuat pesanan kedua', () async {
      build();
      await failedBalanceAttempt();

      await submit(CashierPayMode.balance);

      expect(orders.createCashierOrderCalls, 1);
      // Pembayaran diulang pada pesanan yang SAMA.
      expect(wallet.paidOrderIds, ['ord-k1', 'ord-k1']);
    });

    test('percobaan ulang yang berhasil menuntaskan pesanan yang sama',
        () async {
      build();
      await failedBalanceAttempt();

      wallet.throwOnPay = null; // admin sudah top-up
      final result = await submit(CashierPayMode.balance);

      expect(result?.orderId, 'ord-k1');
      expect(orders.createCashierOrderCalls, 1);
      expect(container.read(cartControllerProvider), isEmpty);
      expect(state().errorMessage, isNull);
    });

    test('menambah item membuat pesanan BARU, bukan memakai yang tertunda',
        () async {
      build();
      await failedBalanceAttempt();

      cart().add(const MenuItemModel(id: 'm2', name: 'Roti', price: 12000));
      await submit(CashierPayMode.balance);

      expect(orders.createCashierOrderCalls, 2);
    });

    test('mengganti tipe pesanan membuat pesanan BARU', () async {
      build();
      await failedBalanceAttempt();

      await cashier().submit(
          mode: CashierPayMode.balance,
          customerName: 'Budi',
          orderType: OrderType.takeaway);

      expect(orders.createCashierOrderCalls, 2);
    });

    test('beralih ke Tunai setelah gagal Saldo membuat pesanan BARU', () async {
      build();
      await failedBalanceAttempt();

      await submit(CashierPayMode.cash);

      expect(orders.createCashierOrderCalls, 2);
    });
  });
}
