import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/api_exception.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/auth/application/auth_controller.dart';
import 'package:rehat_app/features/menu/application/cart_controller.dart';
import 'package:rehat_app/features/order/application/checkout_controller.dart';
import 'package:rehat_app/features/order/data/order_repository.dart';
import 'package:rehat_app/features/wallet/data/wallet_repository.dart';
import 'package:rehat_app/shared/models/cart_item_model.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';
import 'package:rehat_app/shared/models/order_model.dart';

/// PENGUJIAN KARAKTERISASI jalur uang.
///
/// Tujuannya MENGUNCI perilaku yang berlaku sekarang (bukan mendorong desain
/// baru), supaya perubahan berikutnya pada checkout/pembayaran ketahuan.

const _result = CheckoutResult(
  orderId: 'ord-1',
  queueNumber: '',
  subtotal: 30000,
  discountAmount: 0,
  total: 30000,
  paymentMethod: PaymentMethod.qris,
);

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository() : super(client: DioClient(storage: SecureStorage()));

  int createOrderCalls = 0;
  int createGuestOrderCalls = 0;
  String? lastVoucherCode;
  String? lastGuestName;
  String? lastGuestPhone;
  PaymentMethod? lastPaymentMethod;
  Object? throwOnCreate;

  @override
  Future<CheckoutResult> createOrder({
    required List<CartItemModel> items,
    required PaymentMethod paymentMethod,
    OrderType orderType = OrderType.dineIn,
    String? voucherCode,
    String? notes,
    String? tableNumber,
  }) async {
    createOrderCalls++;
    lastVoucherCode = voucherCode;
    lastPaymentMethod = paymentMethod;
    if (throwOnCreate != null) throw throwOnCreate!;
    return _result;
  }

  @override
  Future<CheckoutResult> createGuestOrder({
    required List<CartItemModel> items,
    required PaymentMethod paymentMethod,
    OrderType orderType = OrderType.dineIn,
    String? notes,
    required String guestName,
    String? guestPhone,
    String? tableNumber,
  }) async {
    createGuestOrderCalls++;
    lastGuestName = guestName;
    lastGuestPhone = guestPhone;
    if (throwOnCreate != null) throw throwOnCreate!;
    return _result;
  }

  // `placeOrder` men-invalidate riwayat & pelacakan; keduanya memanggil
  // repository ini. Tanpa override, pengujian menembak Dio SUNGGUHAN.
  @override
  Future<List<OrderModel>> fetchHistory({int page = 1, int limit = 20}) async =>
      const [];

  @override
  Future<List<OrderModel>> fetchAllOrders(
          {String? status, String? date, int page = 1, int limit = 30}) async =>
      const [];

  int get totalCreateCalls => createOrderCalls + createGuestOrderCalls;
}

class _FakeWalletRepository extends WalletRepository {
  _FakeWalletRepository() : super(client: DioClient(storage: SecureStorage()));

  final List<String> paidOrderIds = [];
  Object? throwOnPay;

  @override
  Future<void> payWithBalance(String orderId) async {
    paidOrderIds.add(orderId);
    if (throwOnPay != null) throw throwOnPay!;
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._status);
  final AuthStatus _status;

  int refreshUserCalls = 0;

  @override
  AuthState build() => AuthState(status: _status);

  @override
  Future<void> refreshUser() async => refreshUserCalls++;
}

void main() {
  // `placeOrder` menyentuh binding lewat provider turunan; tanpa ini muncul
  // "Binding has not yet been initialized" secara asinkron.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeOrderRepository orders;
  late _FakeWalletRepository wallet;
  late ProviderContainer container;

  void build({bool guest = false}) {
    orders = _FakeOrderRepository();
    wallet = _FakeWalletRepository();
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(orders),
        walletRepositoryProvider.overrideWithValue(wallet),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
              guest ? AuthStatus.guest : AuthStatus.authenticated),
        ),
      ],
    );
  }

  tearDown(() => container.dispose());

  CheckoutController checkout() =>
      container.read(checkoutControllerProvider.notifier);
  CheckoutState state() => container.read(checkoutControllerProvider);
  CartController cart() => container.read(cartControllerProvider.notifier);

  void fillCart() => cart()
      .add(const MenuItemModel(id: 'm1', name: 'Kopi', price: 30000),
          quantity: 1);

  group('penjagaan sebelum pesanan dibuat', () {
    test('keranjang kosong ditolak tanpa memanggil backend', () async {
      build();

      final result = await checkout().placeOrder();

      expect(result, isNull);
      expect(state().errorMessage, 'Keranjang kosong.');
      expect(orders.totalCreateCalls, 0);
    });

    test('tamu tanpa nama ditolak tanpa memanggil backend', () async {
      build(guest: true);
      fillCart();

      final result = await checkout().placeOrder(guestPhone: '081234567');

      expect(result, isNull);
      expect(state().errorMessage, 'Nama wajib diisi.');
      expect(orders.totalCreateCalls, 0);
    });

    test('tamu tanpa no. HP ditolak', () async {
      build(guest: true);
      fillCart();

      final result = await checkout().placeOrder(guestName: 'Irur');

      expect(result, isNull);
      expect(state().errorMessage,
          'No. HP / WhatsApp wajib diisi (min 8 angka).');
      expect(orders.totalCreateCalls, 0);
    });

    test('no. HP tamu kurang dari 8 ANGKA ditolak walau panjang', () async {
      build(guest: true);
      fillCart();

      // Tanda baca tidak dihitung — hanya digit.
      final result =
          await checkout().placeOrder(guestName: 'Irur', guestPhone: '(0) 8-1');

      expect(result, isNull);
      expect(orders.totalCreateCalls, 0);
    });

    test('keranjang TIDAK dikosongkan saat validasi gagal', () async {
      build(guest: true);
      fillCart();

      await checkout().placeOrder(guestName: '');

      expect(container.read(cartControllerProvider), isNotEmpty);
    });
  });

  group('jalur sukses', () {
    test('pengguna berakun memakai createOrder & mengosongkan keranjang',
        () async {
      build();
      fillCart();

      final result = await checkout().placeOrder();

      expect(result?.orderId, 'ord-1');
      expect(orders.createOrderCalls, 1);
      expect(orders.createGuestOrderCalls, 0);
      expect(container.read(cartControllerProvider), isEmpty);
      expect(container.read(lastCheckoutResultProvider)?.orderId, 'ord-1');
    });

    test('tamu memakai createGuestOrder dengan nama & HP', () async {
      build(guest: true);
      fillCart();

      await checkout().placeOrder(guestName: 'Irur', guestPhone: '087864504924');

      expect(orders.createGuestOrderCalls, 1);
      expect(orders.createOrderCalls, 0);
      expect(orders.lastGuestName, 'Irur');
      expect(orders.lastGuestPhone, '087864504924');
    });

    test('pilihan checkout di-reset setelah pesanan berhasil', () async {
      build();
      fillCart();
      checkout().setOrderType(OrderType.takeaway);
      checkout().setNotes('tanpa gula');

      await checkout().placeOrder();

      expect(state().orderType, OrderType.dineIn);
      expect(state().notes, '');
      expect(state().isSubmitting, isFalse);
      expect(state().errorMessage, isNull);
    });

    test('profil disegarkan untuk pengguna berakun (poin & stamp)', () async {
      build();
      fillCart();

      await checkout().placeOrder();

      final auth = container.read(authControllerProvider.notifier)
          as _FakeAuthController;
      expect(auth.refreshUserCalls, 1);
    });

    test('profil TIDAK disegarkan untuk tamu', () async {
      build(guest: true);
      fillCart();

      await checkout().placeOrder(guestName: 'Irur', guestPhone: '087864504924');

      final auth = container.read(authControllerProvider.notifier)
          as _FakeAuthController;
      expect(auth.refreshUserCalls, 0);
    });
  });

  group('pembayaran Saldo Rehat', () {
    test('memotong saldo untuk pesanan yang baru dibuat', () async {
      build();
      fillCart();
      checkout().setPaymentMethod(PaymentMethod.balance);

      await checkout().placeOrder();

      expect(wallet.paidOrderIds, ['ord-1']);
    });

    test('TIDAK memotong saldo saat metode bayar QRIS', () async {
      build();
      fillCart();

      await checkout().placeOrder();

      expect(wallet.paidOrderIds, isEmpty);
    });

    test('TIDAK memotong saldo untuk tamu (tamu tak punya saldo)', () async {
      build(guest: true);
      fillCart();
      checkout().setPaymentMethod(PaymentMethod.balance);

      await checkout().placeOrder(guestName: 'Irur', guestPhone: '087864504924');

      expect(wallet.paidOrderIds, isEmpty);
    });
  });

  group('kegagalan', () {
    test('ApiException saat membuat pesanan menampilkan pesan server',
        () async {
      build();
      fillCart();
      orders.throwOnCreate =
          ApiException('Menu sedang habis.', code: 'X');

      final result = await checkout().placeOrder();

      expect(result, isNull);
      expect(state().errorMessage, 'Menu sedang habis.');
      expect(state().isSubmitting, isFalse);
      expect(container.read(cartControllerProvider), isNotEmpty);
    });

    test('galat tak dikenal memakai pesan umum', () async {
      build();
      fillCart();
      orders.throwOnCreate = StateError('boom');

      final result = await checkout().placeOrder();

      expect(result, isNull);
      expect(state().errorMessage, 'Gagal membuat pesanan. Silakan coba lagi.');
    });

    test('saldo kurang: pesanan sudah dibuat tapi keranjang tetap terisi',
        () async {
      build();
      fillCart();
      checkout().setPaymentMethod(PaymentMethod.balance);
      wallet.throwOnPay =
          ApiException('Saldo tidak cukup.', code: 'INSUFFICIENT');

      final result = await checkout().placeOrder();

      expect(result, isNull);
      expect(state().errorMessage, 'Saldo tidak cukup.');
      expect(orders.createOrderCalls, 1); // pesanan TERLANJUR dibuat
      expect(container.read(cartControllerProvider), isNotEmpty);
      expect(container.read(lastCheckoutResultProvider), isNull);
    });
  });

  group('ulang bayar setelah saldo kurang (anti pesanan ganda)', () {
    Future<void> failedBalanceAttempt() async {
      fillCart();
      checkout().setPaymentMethod(PaymentMethod.balance);
      wallet.throwOnPay =
          ApiException('Saldo tidak cukup.', code: 'INSUFFICIENT');
      await checkout().placeOrder();
    }

    test('menekan bayar lagi TIDAK membuat pesanan kedua', () async {
      build();
      await failedBalanceAttempt();

      await checkout().placeOrder();

      expect(orders.createOrderCalls, 1);
      // Pembayaran diulang pada pesanan yang SAMA.
      expect(wallet.paidOrderIds, ['ord-1', 'ord-1']);
    });

    test('percobaan ulang yang berhasil menuntaskan pesanan yang sama',
        () async {
      build();
      await failedBalanceAttempt();

      wallet.throwOnPay = null; // mis. pengguna sudah top-up
      final result = await checkout().placeOrder();

      expect(result?.orderId, 'ord-1');
      expect(orders.createOrderCalls, 1);
      expect(container.read(cartControllerProvider), isEmpty);
      expect(container.read(lastCheckoutResultProvider)?.orderId, 'ord-1');
      expect(state().errorMessage, isNull);
    });

    // PENTING: pesanan tertunda hanya boleh dipakai ulang bila isinya SAMA.
    // Kalau tidak, pengguna membayar pesanan yang bukan isi keranjangnya.
    test('menambah item membuat pesanan BARU, bukan memakai yang tertunda',
        () async {
      build();
      await failedBalanceAttempt();

      cart().add(const MenuItemModel(id: 'm2', name: 'Roti', price: 12000));
      await checkout().placeOrder();

      expect(orders.createOrderCalls, 2);
    });

    test('mengubah jumlah item membuat pesanan BARU', () async {
      build();
      await failedBalanceAttempt();

      final id = container.read(cartControllerProvider).first.lineId;
      cart().increment(id);
      await checkout().placeOrder();

      expect(orders.createOrderCalls, 2);
    });

    test('mengganti metode bayar membuat pesanan BARU', () async {
      build();
      await failedBalanceAttempt();

      checkout().setPaymentMethod(PaymentMethod.qris);
      await checkout().placeOrder();

      expect(orders.createOrderCalls, 2);
    });

    test('mengganti tipe pesanan membuat pesanan BARU', () async {
      build();
      await failedBalanceAttempt();

      checkout().setOrderType(OrderType.takeaway);
      await checkout().placeOrder();

      expect(orders.createOrderCalls, 2);
    });

    test('kegagalan BUKAN karena saldo tidak menyisakan pesanan tertunda',
        () async {
      build();
      fillCart();
      orders.throwOnCreate = ApiException('Menu sedang habis.', code: 'X');

      await checkout().placeOrder();
      orders.throwOnCreate = null;
      await checkout().placeOrder();

      // Percobaan pertama gagal SEBELUM pesanan dibuat, jadi percobaan kedua
      // memang harus membuat pesanan (total 2 panggilan, 1 gagal 1 sukses).
      expect(orders.createOrderCalls, 2);
      expect(container.read(cartControllerProvider), isEmpty);
    });
  });
}
