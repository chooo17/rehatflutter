import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/auth/application/auth_controller.dart';
import 'package:rehat_app/features/favorites/application/favorites_controller.dart';
import 'package:rehat_app/features/favorites/data/favorites_repository.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';

// Regresi: tamu yang membuka "Lihat Menu Tanpa Login" terlempar kembali ke
// /login ~1 dtk kemudian. Halaman menu memantau favorit -> GET /favorites
// tanpa token -> 401 -> refresh gagal -> onUnauthorized -> status tamu
// ditimpa `unauthenticated` -> router mengarahkan ke /login.

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void emit(AuthState next) => state = next;
}

class _FakeFavoritesRepository implements FavoritesRepository {
  int fetchCount = 0;

  @override
  Future<List<MenuItemModel>> fetchFavorites() async {
    fetchCount++;
    return const [];
  }

  @override
  Future<void> add(String menuItemId) async {}

  @override
  Future<void> remove(String menuItemId) async {}
}

void main() {
  group('FavoritesController', () {
    late _FakeFavoritesRepository repo;

    ProviderContainer containerFor(AuthStatus status) {
      repo = _FakeFavoritesRepository();
      final c = ProviderContainer(overrides: [
        authControllerProvider
            .overrideWith(() => _FakeAuthController(AuthState(status: status))),
        favoritesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('tamu: TIDAK memanggil GET /favorites, daftar kosong', () async {
      final c = containerFor(AuthStatus.guest);
      final list = await c.read(favoritesControllerProvider.future);
      expect(list, isEmpty);
      expect(repo.fetchCount, 0);
    });

    test('belum login: TIDAK memanggil GET /favorites', () async {
      final c = containerFor(AuthStatus.unauthenticated);
      await c.read(favoritesControllerProvider.future);
      expect(repo.fetchCount, 0);
    });

    test('login: memanggil GET /favorites', () async {
      final c = containerFor(AuthStatus.authenticated);
      await c.read(favoritesControllerProvider.future);
      expect(repo.fetchCount, 1);
    });

    test('tamu lalu login: favorit dimuat setelah login', () async {
      final c = containerFor(AuthStatus.guest);
      final sub = c.listen(favoritesControllerProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(favoritesControllerProvider.future);
      expect(repo.fetchCount, 0);

      (c.read(authControllerProvider.notifier) as _FakeAuthController)
          .emit(const AuthState(status: AuthStatus.authenticated));
      await c.read(favoritesControllerProvider.future);
      expect(repo.fetchCount, 1);
    });
  });

  group('sessionExpiredState', () {
    test('tamu tetap tamu saat ada 401 yang gagal di-refresh', () {
      expect(
        sessionExpiredState(const AuthState(status: AuthStatus.guest)),
        isNull,
      );
    });

    test('sudah unauthenticated: tidak ada perubahan', () {
      expect(
        sessionExpiredState(
            const AuthState(status: AuthStatus.unauthenticated)),
        isNull,
      );
    });

    test('login: sesi berakhir -> unauthenticated', () {
      final next = sessionExpiredState(
          const AuthState(status: AuthStatus.authenticated));
      expect(next?.status, AuthStatus.unauthenticated);
    });
  });
}
