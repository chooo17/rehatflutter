import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/free_drink_repository.dart';

/// Status pencarian & penukaran voucher gratis-minuman di kasir.
class FreeDrinkState {
  const FreeDrinkState({
    this.isLoading = false,
    this.usingId,
    this.vouchers = const [],
    this.errorMessage,
    this.searched = false,
  });

  final bool isLoading;

  /// Id voucher yang sedang ditandai-terpakai (null = tak ada).
  final String? usingId;

  final List<FreeDrinkVoucher> vouchers;
  final String? errorMessage;

  /// True setelah setidaknya satu pencarian dijalankan (untuk empty-state).
  final bool searched;

  FreeDrinkState copyWith({
    bool? isLoading,
    String? usingId,
    bool clearUsingId = false,
    List<FreeDrinkVoucher>? vouchers,
    String? errorMessage,
    bool clearError = false,
    bool? searched,
  }) {
    return FreeDrinkState(
      isLoading: isLoading ?? this.isLoading,
      usingId: clearUsingId ? null : (usingId ?? this.usingId),
      vouchers: vouchers ?? this.vouchers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searched: searched ?? this.searched,
    );
  }
}

class FreeDrinkController extends Notifier<FreeDrinkState> {
  @override
  FreeDrinkState build() => const FreeDrinkState();

  /// Cari voucher aktif pelanggan via HP (+ nama opsional).
  Future<void> lookup({required String phone, String? name}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await ref
          .read(freeDrinkRepositoryProvider)
          .lookup(phone: phone, name: name);
      state = state.copyWith(
          isLoading: false, vouchers: list, searched: true, clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(
          isLoading: false, vouchers: const [], searched: true, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
          isLoading: false,
          vouchers: const [],
          searched: true,
          errorMessage: 'Gagal mencari voucher. Coba lagi.');
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
