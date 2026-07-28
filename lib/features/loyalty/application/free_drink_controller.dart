import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/free_drink_repository.dart';

/// Status pencarian & penukaran voucher gratis-minuman di kasir.
class FreeDrinkState {
  const FreeDrinkState({
    this.isLoading = false,
    this.usingId,
    this.vouchers = const [],
    this.stampCandidates = const [],
    this.redeemingUserId,
    this.errorMessage,
    this.searched = false,
  });

  final bool isLoading;

  /// Id voucher yang sedang ditandai-terpakai (null = tak ada).
  final String? usingId;

  final List<FreeDrinkVoucher> vouchers;

  /// Pelanggan yang stamp-nya siap ditukar langsung oleh kasir.
  final List<StampRedeemCandidate> stampCandidates;

  /// userId yang stamp-nya sedang ditukar (null = tak ada).
  final String? redeemingUserId;

  final String? errorMessage;

  /// True setelah setidaknya satu pencarian dijalankan (untuk empty-state).
  final bool searched;

  FreeDrinkState copyWith({
    bool? isLoading,
    String? usingId,
    bool clearUsingId = false,
    List<FreeDrinkVoucher>? vouchers,
    List<StampRedeemCandidate>? stampCandidates,
    String? redeemingUserId,
    bool clearRedeemingUserId = false,
    String? errorMessage,
    bool clearError = false,
    bool? searched,
  }) {
    return FreeDrinkState(
      isLoading: isLoading ?? this.isLoading,
      usingId: clearUsingId ? null : (usingId ?? this.usingId),
      vouchers: vouchers ?? this.vouchers,
      stampCandidates: stampCandidates ?? this.stampCandidates,
      redeemingUserId: clearRedeemingUserId
          ? null
          : (redeemingUserId ?? this.redeemingUserId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searched: searched ?? this.searched,
    );
  }
}

class FreeDrinkController extends Notifier<FreeDrinkState> {
  @override
  FreeDrinkState build() => const FreeDrinkState();

  // Urutan pencarian: untuk typeahead live, respons lama TAK BOLEH menimpa hasil
  // pencarian yang lebih baru (balapan jaringan).
  int _seq = 0;

  /// Kosongkan hasil (mis. input HP terlalu pendek). Membatalkan efek respons
  /// pencarian yang masih berjalan.
  void clearResults() {
    _seq++;
    state = state.copyWith(
        isLoading: false,
        vouchers: const [],
        stampCandidates: const [],
        searched: false,
        clearError: true);
  }

  /// Cari voucher aktif + pelanggan siap-tukar-stamp via HP (+ nama opsional).
  /// Kedua sumber diambil paralel. Aman dipanggil berulang saat mengetik
  /// (debounce di UI); hanya respons TERBARU yang dipakai (kunci `_seq`).
  Future<void> lookup({required String phone, String? name}) async {
    final mySeq = ++_seq;
    state = state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(freeDrinkRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.lookup(phone: phone, name: name),
        repo.lookupStamps(phone: phone, name: name),
      ]);
      if (mySeq != _seq) return; // ada pencarian lebih baru → abaikan hasil ini
      state = state.copyWith(
        isLoading: false,
        vouchers: results[0] as List<FreeDrinkVoucher>,
        stampCandidates: results[1] as List<StampRedeemCandidate>,
        searched: true,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (mySeq != _seq) return;
      state = state.copyWith(
          isLoading: false,
          vouchers: const [],
          stampCandidates: const [],
          searched: true,
          errorMessage: e.message);
    } catch (_) {
      if (mySeq != _seq) return;
      state = state.copyWith(
          isLoading: false,
          vouchers: const [],
          stampCandidates: const [],
          searched: true,
          errorMessage: 'Gagal mencari voucher. Coba lagi.');
    }
  }

  /// Tukar 9 stamp pelanggan + langsung serahkan minuman. Sukses → segarkan
  /// hasil pencarian (sisa stamp berkurang / kandidat hilang). Return true bila sukses.
  Future<bool> redeemStampFor(StampRedeemCandidate c,
      {required String phone, String? name}) async {
    state = state.copyWith(redeemingUserId: c.userId, clearError: true);
    try {
      await ref.read(freeDrinkRepositoryProvider).redeemForCustomer(c.userId);
      state = state.copyWith(clearRedeemingUserId: true);
      // Segarkan agar sisa stamp / voucher terbaru tampil.
      await lookup(phone: phone, name: name);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(clearRedeemingUserId: true, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
          clearRedeemingUserId: true,
          errorMessage: 'Gagal menukar stamp. Coba lagi.');
      return false;
    }
  }

  /// Tandai satu voucher terpakai; hapus dari daftar bila sukses.
  /// Mengembalikan true bila berhasil.
  Future<bool> markUsed(String voucherId) async {
    state = state.copyWith(usingId: voucherId, clearError: true);
    try {
      await ref.read(freeDrinkRepositoryProvider).markUsed(voucherId);
      state = state.copyWith(
        clearUsingId: true,
        vouchers:
            state.vouchers.where((v) => v.voucherId != voucherId).toList(),
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(clearUsingId: true, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
          clearUsingId: true, errorMessage: 'Gagal menandai terpakai. Coba lagi.');
      return false;
    }
  }

  void reset() => state = const FreeDrinkState();
}

final freeDrinkControllerProvider =
    NotifierProvider<FreeDrinkController, FreeDrinkState>(
        FreeDrinkController.new);
