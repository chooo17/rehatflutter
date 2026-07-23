import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/auth/application/auth_controller.dart';
import 'package:rehat_app/shared/models/user_model.dart';

class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);

  void emit(AuthState next) => state = next;
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(_FakeAuthController.new)],
    );
  });
  tearDown(() => container.dispose());

  _FakeAuthController auth() =>
      container.read(authControllerProvider.notifier) as _FakeAuthController;

  /// Menghitung berapa kali [provider] MEMBERI TAHU pendengarnya: perubahan
  /// AuthState yang tak relevan tidak boleh membangunkan layar.
  ///
  /// Notifikasi Riverpod di-flush asinkron - WAJIB menunggu satu putaran
  /// event loop, kalau tidak setiap pengujian "tidak memberi tahu" lulus
  /// secara semu (callback belum sempat jalan saat langganan ditutup).
  Future<int> countNotifications<T>(
    ProviderListenable<T> provider,
    void Function() act,
  ) async {
    var notifications = 0;
    final sub = container.listen(provider, (_, __) => notifications++);
    act();
    await Future<void>.delayed(Duration.zero);
    sub.close();
    return notifications;
  }

  group('isGuestProvider', () {
    test('mengikuti status auth', () {
      expect(container.read(isGuestProvider), isFalse);
      auth().emit(const AuthState(status: AuthStatus.guest));
      expect(container.read(isGuestProvider), isTrue);
    });

    test('TIDAK memberi tahu saat errorMessage berubah', () async {
      final n = await countNotifications(isGuestProvider, () {
        auth().emit(const AuthState(
          status: AuthStatus.authenticated,
          errorMessage: 'Nomor atau kata sandi salah',
        ));
      });
      expect(n, 0);
    });

    test('TIDAK memberi tahu saat isSubmitting berubah', () async {
      final n = await countNotifications(isGuestProvider, () {
        auth().emit(const AuthState(
          status: AuthStatus.authenticated,
          isSubmitting: true,
        ));
      });
      expect(n, 0);
    });

    test('memberi tahu saat status benar-benar berubah', () async {
      final n = await countNotifications(isGuestProvider, () {
        auth().emit(const AuthState(status: AuthStatus.guest));
      });
      expect(n, 1);
    });
  });

  group('isAdminProvider', () {
    const user = UserModel(id: 'u1', name: 'Irur', phone: '08123');

    test('TIDAK memberi tahu saat errorMessage berubah', () async {
      final n = await countNotifications(isAdminProvider, () {
        auth().emit(const AuthState(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: 'gagal',
        ));
      });
      expect(n, 0);
    });

    test('TIDAK memberi tahu saat avatar pengguna diperbarui', () async {
      auth().emit(const AuthState(status: AuthStatus.authenticated, user: user));
      final n = await countNotifications(isAdminProvider, () {
        auth().emit(const AuthState(
          status: AuthStatus.authenticated,
          user: UserModel(
            id: 'u1',
            name: 'Irur',
            phone: '08123',
            avatarUrl: 'https://contoh/baru.png',
          ),
        ));
      });
      expect(n, 0);
    });
  });

  group('currentUserProvider', () {
    test('memberi tahu saat pengguna berubah', () async {
      final n = await countNotifications(currentUserProvider, () {
        auth().emit(const AuthState(
          status: AuthStatus.authenticated,
          user: UserModel(id: 'u1', name: 'Irur', phone: '08123'),
        ));
      });
      expect(n, 1);
    });

    test('TIDAK memberi tahu saat hanya isSubmitting berubah', () async {
      auth().emit(const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: 'u1', name: 'Irur', phone: '08123'),
      ));
      final n = await countNotifications(currentUserProvider, () {
        auth().emit(const AuthState(
          status: AuthStatus.authenticated,
          user: UserModel(id: 'u1', name: 'Irur', phone: '08123'),
          isSubmitting: true,
        ));
      });
      expect(n, 0);
    });
  });
}

