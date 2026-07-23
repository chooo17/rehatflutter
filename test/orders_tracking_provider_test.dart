import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/core/utils/app_lifecycle.dart';
import 'package:rehat_app/features/auth/application/auth_controller.dart';
import 'package:rehat_app/features/order/data/order_repository.dart';
import 'package:rehat_app/shared/models/order_model.dart';

/// Repository palsu yang MENGHITUNG panggilan jaringan — inti dari pengujian
/// ini adalah "berapa kali kita menembak backend", bukan isi datanya.
class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository() : super(client: DioClient(storage: SecureStorage()));

  int historyCalls = 0;
  int allOrdersCalls = 0;

  @override
  Future<List<OrderModel>> fetchHistory({int page = 1, int limit = 20}) async {
    historyCalls++;
    return const [];
  }

  @override
  Future<List<OrderModel>> fetchAllOrders(
      {String? status, String? date, int page = 1, int limit = 30}) async {
    allOrdersCalls++;
    return const [];
  }

  int get totalCalls => historyCalls + allOrdersCalls;
}

/// AuthController palsu: `build()` tidak memanggil super sehingga tak ada
/// dependensi jaringan/storage yang perlu disiapkan.
class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);

  void emit(AuthState next) => state = next;
}

void main() {
  late _FakeOrderRepository repo;
  late ProviderContainer container;

  ProviderContainer build({bool foreground = true}) {
    repo = _FakeOrderRepository();
    return ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(_FakeAuthController.new),
        appForegroundProvider.overrideWith((ref) => foreground),
      ],
    );
  }

  tearDown(() => container.dispose());

  test('polling menembak backend saat aplikasi di depan (foreground)', () async {
    container = build(foreground: true);
    container.listen(ordersTrackingProvider, (_, __) {});

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repo.totalCalls, greaterThan(0));
  });

  test('polling TIDAK menembak backend saat aplikasi di background', () async {
    container = build(foreground: false);
    container.listen(ordersTrackingProvider, (_, __) {});

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repo.totalCalls, 0);
  });

  test('perubahan errorMessage TIDAK me-restart polling', () async {
    container = build(foreground: true);
    container.listen(ordersTrackingProvider, (_, __) {});

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final callsAfterFirstFetch = repo.totalCalls;
    expect(callsAfterFirstFetch, greaterThan(0));

    // Perubahan state auth yang TIDAK relevan bagi polling (mis. login gagal
    // menulis pesan error). Tanpa `.select`, stream ikut dibangun ulang dan
    // langsung menembak backend lagi.
    (container.read(authControllerProvider.notifier) as _FakeAuthController)
        .emit(const AuthState(
      status: AuthStatus.authenticated,
      errorMessage: 'Nomor atau kata sandi salah',
    ));

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repo.totalCalls, callsAfterFirstFetch);
  });
}
