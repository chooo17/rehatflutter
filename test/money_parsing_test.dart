import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/order/application/checkout_controller.dart';
import 'package:rehat_app/features/order/data/order_repository.dart';
import 'package:rehat_app/features/wallet/data/wallet_repository.dart';

/// PENGUJIAN KARAKTERISASI untuk angka-angka UANG.
///
/// Nilai rupiah masuk lewat pengurai yang "pemaaf" (`_int`): apa pun yang tak
/// dikenal menjadi 0, TANPA melempar error. Perilaku itu dikunci di sini agar
/// terlihat, dan agar perubahannya tidak lolos diam-diam.

void main() {
  group('WalletTxn.fromJson — jumlah rupiah', () {
    test('membaca bilangan bulat', () {
      final t = WalletTxn.fromJson({
        'amount': 50000,
        'type': 'topup',
        'description': 'Top-up DOKU',
        'created_at': '2026-07-20T03:00:00Z',
      });
      expect(t.amount, 50000);
      expect(t.type, 'topup');
    });

    test('membaca angka dalam bentuk String', () {
      final t = WalletTxn.fromJson({'amount': '25000'});
      expect(t.amount, 25000);
    });

    test('membulatkan desimal ke bawah (num -> int)', () {
      final t = WalletTxn.fromJson({'amount': 19999.99});
      expect(t.amount, 19999);
    });

    test('nilai null menjadi 0 — TIDAK melempar error', () {
      expect(WalletTxn.fromJson({'amount': null}).amount, 0);
    });

    test('String tak terbaca menjadi 0 — TIDAK melempar error', () {
      expect(WalletTxn.fromJson({'amount': 'lima ribu'}).amount, 0);
    });

    test('created_at tak terbaca jatuh ke waktu sekarang', () {
      final before = DateTime.now();
      final t = WalletTxn.fromJson({'created_at': 'bukan-tanggal'});
      expect(t.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
          isFalse);
    });
  });

  group('ReferralInfo.fromJson', () {
    test('memetakan referred_count & reward_pct', () {
      final r = ReferralInfo.fromJson({
        'code': 'IRUR15',
        'referred_count': 3,
        'reward_pct': 15,
      });
      expect(r.code, 'IRUR15');
      expect(r.referredCount, 3);
      expect(r.rewardPct, 15);
    });

    test('field kosong aman (kode kosong, angka 0)', () {
      final r = ReferralInfo.fromJson({});
      expect(r.code, '');
      expect(r.referredCount, 0);
      expect(r.rewardPct, 0);
    });
  });

  group('CheckoutState.discountAmount — potongan hanya bila voucher SAH', () {
    test('tanpa voucher, potongan 0', () {
      expect(const CheckoutState().discountAmount, 0);
    });

    test('voucher sah memberi potongan', () {
      const s = CheckoutState(
        voucherCode: 'HEMAT15',
        voucher: VoucherValidation(isValid: true, discountAmount: 4500),
      );
      expect(s.discountAmount, 4500);
    });

    test('voucher TIDAK sah tetap 0 walau membawa nominal', () {
      const s = CheckoutState(
        voucherCode: 'PALSU',
        voucher: VoucherValidation(isValid: false, discountAmount: 99000),
      );
      expect(s.discountAmount, 0);
    });
  });
}
