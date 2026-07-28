import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/api_exception.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/loyalty/application/free_drink_controller.dart';
import 'package:rehat_app/features/loyalty/data/free_drink_repository.dart';

/// Pengujian controller kasir untuk voucher gratis-minuman (lookup + tandai
/// terpakai). Mengunci: hasil lookup, penghapusan setelah terpakai, & error.

FreeDrinkVoucher _v(String id, String name) =>
    FreeDrinkVoucher(voucherId: id, code: 'CODE-$id', customerName: name);

StampRedeemCandidate _c(String userId, String name, {int stamps = 9}) =>
    StampRedeemCandidate(
      userId: userId,
      name: name,
      availableStamps: stamps,
      redeemableRewards: stamps ~/ 9,
    );

class _FakeRepo extends FreeDrinkRepository {
  _FakeRepo() : super(client: DioClient(storage: SecureStorage()));

  List<FreeDrinkVoucher> lookupResult = const [];
  List<StampRedeemCandidate> stampResult = const [];
  Object? throwOnLookup;
  Object? throwOnUse;
  Object? throwOnRedeem;
  final List<String> usedIds = [];
  final List<String> redeemedUserIds = [];

  @override
  Future<List<FreeDrinkVoucher>> lookup(
      {required String phone, String? name}) async {
    if (throwOnLookup != null) throw throwOnLookup!;
    return lookupResult;
  }

  @override
  Future<List<StampRedeemCandidate>> lookupStamps(
      {required String phone, String? name}) async {
    if (throwOnLookup != null) throw throwOnLookup!;
    return stampResult;
  }

  @override
  Future<void> markUsed(String voucherId) async {
    if (throwOnUse != null) throw throwOnUse!;
    usedIds.add(voucherId);
  }

  @override
  Future<void> redeemForCustomer(String userId) async {
    if (throwOnRedeem != null) throw throwOnRedeem!;
    redeemedUserIds.add(userId);
    // Setelah ditukar, stamp turun di bawah target → kandidat hilang saat refresh.
    stampResult = stampResult.where((c) => c.userId != userId).toList();
  }
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  void build() {
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [freeDrinkRepositoryProvider.overrideWithValue(repo)],
    );
  }

  tearDown(() => container.dispose());

  FreeDrinkController ctrl() =>
      container.read(freeDrinkControllerProvider.notifier);
  FreeDrinkState state() => container.read(freeDrinkControllerProvider);

  group('lookup', () {
    test('mengisi daftar voucher & menandai sudah mencari', () async {
      build();
      repo.lookupResult = [_v('1', 'Budi'), _v('2', 'Budi')];

      await ctrl().lookup(phone: '0878');

      expect(state().vouchers.length, 2);
      expect(state().searched, isTrue);
      expect(state().isLoading, isFalse);
      expect(state().errorMessage, isNull);
    });

    test('menggabung voucher & kandidat stamp dari dua sumber', () async {
      build();
      repo.lookupResult = [_v('1', 'Budi')];
      repo.stampResult = [_c('u1', 'Ani', stamps: 18)];

      await ctrl().lookup(phone: '0878');

      expect(state().vouchers.length, 1);
      expect(state().stampCandidates.length, 1);
      expect(state().stampCandidates.first.redeemableRewards, 2);
      expect(state().searched, isTrue);
    });

    test('tanpa hasil → daftar kosong tapi tetap "searched"', () async {
      build();
      repo.lookupResult = const [];

      await ctrl().lookup(phone: '0000');

      expect(state().vouchers, isEmpty);
      expect(state().searched, isTrue);
    });

    test('ApiException menampilkan pesan server', () async {
      build();
      repo.throwOnLookup = ApiException('Masukkan minimal 6 angka.', code: 'X');

      await ctrl().lookup(phone: '1');

      expect(state().errorMessage, 'Masukkan minimal 6 angka.');
      expect(state().vouchers, isEmpty);
    });
  });

  group('tandai terpakai', () {
    test('sukses menghapus voucher dari daftar', () async {
      build();
      repo.lookupResult = [_v('1', 'Budi'), _v('2', 'Ani')];
      await ctrl().lookup(phone: '0878');

      final ok = await ctrl().markUsed('1');

      expect(ok, isTrue);
      expect(repo.usedIds, ['1']);
      expect(state().vouchers.map((v) => v.voucherId), ['2']);
      expect(state().usingId, isNull);
    });

    test('voucher sudah dipakai → error, daftar tak berubah', () async {
      build();
      repo.lookupResult = [_v('1', 'Budi')];
      await ctrl().lookup(phone: '0878');
      repo.throwOnUse = ApiException('Voucher sudah dipakai', code: 'USED');

      final ok = await ctrl().markUsed('1');

      expect(ok, isFalse);
      expect(state().errorMessage, 'Voucher sudah dipakai');
      expect(state().vouchers.length, 1); // tetap ada
      expect(state().usingId, isNull);
    });
  });

  group('tukar stamp kasir', () {
    test('sukses menukar → panggil repo & refresh (kandidat hilang)', () async {
      build();
      repo.stampResult = [_c('u1', 'Ani'), _c('u2', 'Budi')];
      await ctrl().lookup(phone: '0878');

      final target = state().stampCandidates.firstWhere((c) => c.userId == 'u1');
      final ok = await ctrl().redeemStampFor(target, phone: '0878');

      expect(ok, isTrue);
      expect(repo.redeemedUserIds, ['u1']);
      // Refresh: u1 sudah turun di bawah target → tinggal u2.
      expect(state().stampCandidates.map((c) => c.userId), ['u2']);
      expect(state().redeemingUserId, isNull);
    });

    test('stamp kurang → error, redeemingUserId dibersihkan', () async {
      build();
      repo.stampResult = [_c('u1', 'Ani')];
      await ctrl().lookup(phone: '0878');
      repo.throwOnRedeem =
          ApiException('Stamp belum cukup.', code: 'STAMP_NOT_ENOUGH');

      final target = state().stampCandidates.first;
      final ok = await ctrl().redeemStampFor(target, phone: '0878');

      expect(ok, isFalse);
      expect(state().errorMessage, 'Stamp belum cukup.');
      expect(state().redeemingUserId, isNull);
    });
  });
}
