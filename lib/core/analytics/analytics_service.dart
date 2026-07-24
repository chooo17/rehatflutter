import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Pembungkus Firebase Analytics yang AMAN: semua panggilan menjadi no-op bila
/// Firebase tak terinisialisasi (mis. web, atau init gagal). Dengan begitu
/// instrumentasi funnel bisa dipasang di mana saja tanpa risiko crash.
///
/// Diaktifkan hanya lewat [enable] setelah `Firebase.initializeApp()` sukses
/// (lihat `main.dart` — hanya di mobile saat `firebaseReady`).
class Analytics {
  Analytics._();

  static FirebaseAnalytics? _fa;
  static bool _enabled = false;

  /// Aktifkan setelah Firebase siap. Aman dipanggil berulang.
  static void enable() {
    if (_enabled) return;
    try {
      _fa = FirebaseAnalytics.instance;
      _enabled = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] gagal aktif: $e');
    }
  }

  /// Untuk `FirebaseAnalyticsObserver` (screen_view otomatis). null bila non-aktif.
  static FirebaseAnalytics? get instance => _enabled ? _fa : null;

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_enabled || _fa == null) return;
    try {
      await _fa!.logEvent(name: name, parameters: params);
    } catch (_) {
      /* jangan pernah mengganggu alur karena analitik */
    }
  }

  // ─── Event funnel bernama (parameter minimal, tanpa data pribadi) ───────────

  static Future<void> signUp() => _log('sign_up', {'method': 'otp'});

  static Future<void> login() => _log('login', {'method': 'otp'});

  static Future<void> addToCart({int? quantity}) =>
      _log('add_to_cart', {if (quantity != null) 'quantity': quantity});

  static Future<void> beginCheckout({int? value, String? paymentMethod}) =>
      _log('begin_checkout', {
        if (value != null) 'value': value,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      });

  /// Pesanan berhasil dibuat (belum tentu terbayar). `source`: app/cashier.
  static Future<void> orderCreated(
          {int? value, String? paymentMethod, required String source}) =>
      _log('order_created', {
        if (value != null) 'value': value,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        'source': source,
      });

  static Future<void> redeemStamp() => _log('redeem_stamp');

  static Future<void> redeemPoints({required int discountPct}) =>
      _log('redeem_points', {'discount_pct': discountPct});

  static Future<void> referralShare() => _log('referral_share');
}
