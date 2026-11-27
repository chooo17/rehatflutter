// test/checkout_delivery_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/auth/application/auth_controller.dart';
import 'package:rehat_app/features/delivery/data/delivery_repository.dart';
import 'package:rehat_app/features/menu/application/cart_controller.dart';
import 'package:rehat_app/features/order/application/checkout_controller.dart';
import 'package:rehat_app/features/order/data/order_repository.dart';
import 'package:rehat_app/shared/models/cart_item_model.dart';
import 'package:rehat_app/shared/models/delivery_models.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';
import 'package:rehat_app/shared/models/order_model.dart';

class _FakeOrders extends OrderRepository {
  _FakeOrders() : super(client: DioClient(storage: SecureStorage()));
  int creates = 0;
  OrderType? lastType;
  String? lastAddressId;

  @override
  Future<CheckoutResult> createOrder({
    required List<CartItemModel> items,
    required PaymentMethod paymentMethod,
    OrderType orderType = OrderType.dineIn,
    String? voucherCode,
    String? notes,
    String? tableNumber,
    String? addressId,
  }) async {
    creates++;
    lastType = orderType;
    lastAddressId = addressId;
    return const CheckoutResult(
        orderId: 'o1', queueNumber: '', subtotal: 30000, discountAmount: 0,
        total: 35000, deliveryFee: 5000, paymentMethod: PaymentMethod.qris, orderType: OrderType.delivery);
  }

  @override
  Future<List<OrderModel>> fetchHistory({int page = 1, int limit = 20}) async => const [];
  @override
  Future<List<OrderModel>> fetchAllOrders({String? status, String? date, int page = 1, int limit = 30}) async => const [];
}

class _FakeDelivery extends DeliveryRepository {
  _FakeDelivery() : super(client: DioClient(storage: SecureStorage()));
  List<AddressModel> addresses = const [
    AddressModel(id: 'a1', label: 'Kantor', addressText: 'Jl. A', recipientName: 'N', recipientPhone: '0812', lat: 0, lng: 0),
    AddressModel(id: 'a2', label: 'Rumah', addressText: 'Jl. B', recipientName: 'N', recipientPhone: '0812', lat: 0, lng: 0, isDefault: true),
  ];
  DeliveryQuote nextQuote = const DeliveryQuote(available: true, distanceM: 1200, deliveryFee: 5000, freeDeliveryMin: 50000, remainingForFree: 20000);
  final List<(String, int)> quoteCalls = [];

  @override
  Future<List<AddressModel>> fetchAddresses() async => addresses;
  @override
  Future<DeliveryQuote> quote({required String addressId, required int itemsNet}) async {
    quoteCalls.add((addressId, itemsNet));
    return nextQuote;
  }
}

class _FakeAuth extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
  @override
  Future<void> refreshUser() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeOrders orders;
  late _FakeDelivery delivery;
  late ProviderContainer c;

  setUp(() {
    orders = _FakeOrders();
    delivery = _FakeDelivery();
    c = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(orders),
      deliveryRepositoryProvider.overrideWithValue(delivery),
      authControllerProvider.overrideWith(_FakeAuth.new),
    ]);
    c.read(cartControllerProvider.notifier)
        .add(const MenuItemModel(id: 'm1', name: 'Kopi', price: 30000), quantity: 1);
  });
  tearDown(() => c.dispose());

  CheckoutController ctl() => c.read(checkoutControllerProvider.notifier);
  CheckoutState st() => c.read(checkoutControllerProvider);

  test('useDelivery memilih alamat default & mengambil quote dari total menu', () async {
    await ctl().useDelivery();
    expect(st().orderType, OrderType.delivery);
    expect(st().addressId, 'a2');
    expect(delivery.quoteCalls.single, ('a2', 30000));
    expect(st().deliveryFee, 5000);
  });

  test('deliveryFee 0 bila bukan delivery', () async {
    await ctl().useDelivery();
    ctl().setOrderType(OrderType.takeaway);
    expect(st().deliveryFee, 0);
  });

  test('pesan delivery tanpa alamat ditolak tanpa memanggil backend', () async {
    delivery.addresses = const [];
    await ctl().useDelivery();
    final r = await ctl().placeOrder();
    expect(r, isNull);
    expect(st().errorMessage, 'Pilih alamat pengiriman.');
    expect(orders.creates, 0);
  });

  test('alamat di luar jangkauan ditolak dengan pesan dari server', () async {
    delivery.nextQuote = const DeliveryQuote(available: false, reason: 'OUT_OF_RADIUS', message: 'Di luar jangkauan');
    await ctl().useDelivery();
    final r = await ctl().placeOrder();
    expect(r, isNull);
    expect(st().errorMessage, 'Di luar jangkauan');
    expect(orders.creates, 0);
  });

  test('pesan delivery sukses mengirim tipe delivery & address_id', () async {
    await ctl().useDelivery();
    final r = await ctl().placeOrder();
    expect(r, isNotNull);
    expect(orders.lastType, OrderType.delivery);
    expect(orders.lastAddressId, 'a2');
  });

  test('ganti alamat mengambil quote baru', () async {
    await ctl().useDelivery();
    await ctl().selectAddress('a1');
    expect(st().addressId, 'a1');
    expect(delivery.quoteCalls.last.$1, 'a1');
  });

  test('takeaway tidak mengirim address_id', () async {
    await ctl().useDelivery();
    ctl().setOrderType(OrderType.takeaway);
    await ctl().placeOrder();
    expect(orders.lastType, OrderType.takeaway);
    expect(orders.lastAddressId, isNull);
  });
}
