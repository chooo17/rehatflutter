import 'package:flutter/foundation.dart';

/// Konstanta endpoint API backend (Node.js + Supabase).
class ApiConstants {
  ApiConstants._();

  /// Host backend saat pengembangan.
  ///
  /// - **Android emulator**: `10.0.2.2` (loopback host dari emulator), otomatis.
  /// - **Web / iOS simulator / desktop**: `localhost`.
  /// - **HP Android fisik**: ganti [_devHost] ke IP LAN Pmu (mis. `10.20.25.15`).
  static const String _port = '3000';

  static String get _host {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  /// URL backend produksi, di-inject saat build:
  /// `flutter build web --dart-define=API_BASE_URL=https://api.domainmu/v1`
  /// Bila kosong, memakai host dev otomatis (localhost / 10.0.2.2).
  static const String _prodBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// Base URL backend (`/v1`). Produksi bila `API_BASE_URL` di-set saat build,
  /// selain itu jatuh ke host pengembangan lokal.
  static String get baseUrl =>
      _prodBaseUrl.isNotEmpty ? _prodBaseUrl : 'http://$_host:$_port/v1';

  /// URL web app pelanggan (untuk QR meja: `<web>/?table=N`). Bisa di-override
  /// saat build: `--dart-define=WEB_APP_URL=https://domainmu`.
  static const String webAppUrl = String.fromEnvironment('WEB_APP_URL',
      defaultValue: 'https://rehatflutter.vercel.app');

  // Auth ----------------------------------------------------------------
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // User ----------------------------------------------------------------
  static const String me = '/users/me';
  static const String updateProfile = '/users/me';
  static const String avatar = '/users/me/avatar';

  // Menu ----------------------------------------------------------------
  static const String menu = '/menu/items';
  static const String featuredMenu = '/menu/featured';
  static const String menuCategories = '/menu/categories';
  static String menuDetail(String id) => '/menu/items/$id';
  static String menuItemImage(String id) => '/menu/items/$id/image';
  static String menuItemUpdate(String id) => '/menu/items/$id'; // PATCH (HPP dll)

  // Order ---------------------------------------------------------------
  static const String orders = '/orders'; // POST buat, GET riwayat (paginated)
  static const String ordersGuest = '/orders/guest'; // POST pesanan tamu

  static String orderDetail(String id) => '/orders/$id';
  static String reorder(String id) => '/orders/$id/reorder';
  static String orderStatus(String id) => '/orders/$id/status'; // GET publik / PATCH admin
  static String orderPay(String id) => '/orders/$id/pay';
  static String orderQris(String id) => '/orders/$id/qris'; // DOKU QRIS API

  // Admin orders -------------------------------------------------------
  static const String adminOrders = '/admin/orders';
  static String adminOrderDetail(String id) => '/admin/orders/$id';
  static const String adminSalesReport = '/admin/reports/sales';
  static const String adminReportCalendar = '/admin/reports/calendar';
  static const String adminClosingReport = '/admin/reports/closing';
  static const String adminCustomerSegments = '/admin/customers/segments';
  static const String adminBroadcast = '/admin/broadcast';
  static const String adminAnalytics = '/admin/reports/analytics';

  // Referral & Wallet -------------------------------------------------
  static const String referralMe = '/referrals/me';
  static const String referralApply = '/referrals/apply';
  static const String wallet = '/wallet';
  static const String walletTopup = '/wallet/topup';
  static String orderPayBalance(String id) => '/orders/$id/pay-balance';
  static String adminOrderPayBalance(String id) => '/admin/orders/$id/pay-balance';
  static String adminOrderRefund(String id) => '/admin/orders/$id/refund'; // POST refund tunai
  static const String adminExpenses = '/admin/expenses';
  static String adminExpense(String id) => '/admin/expenses/$id';

  // Voucher -------------------------------------------------------------
  static const String vouchers = '/vouchers';
  static const String voucherValidate = '/vouchers/validate';

  // Review --------------------------------------------------------------
  static const String reviews = '/reviews';
  static String menuItemReviews(String id) => '/menu/items/$id/reviews';

  // Spin & Loyalty ------------------------------------------------------
  static const String spinStatus = '/spin/status';
  static const String spin = '/spin';
  static const String loyalty = '/loyalty';
  static const String loyaltyHistory = '/loyalty/history';
  static const String loyaltyStampRedeem = '/loyalty/stamps/redeem';
  static const String loyaltyPointsRedeem = '/loyalty/points/redeem';
  // Voucher gratis-minuman (kasir): cari via HP+nama, tandai terpakai.
  static const String freeDrinkVouchers = '/admin/free-drink-vouchers';
  static String freeDrinkVoucherUse(String id) =>
      '/admin/free-drink-vouchers/$id/use';
  // Tukar stamp pelanggan dari sisi kasir: cari pelanggan siap-tukar & tukar+serah.
  static const String stampLookup = '/admin/stamp-lookup';
  static const String stampRedeem = '/admin/stamp-redeem';

  // Favorites -----------------------------------------------------------
  static const String favorites = '/favorites';
  static String favorite(String menuItemId) => '/favorites/$menuItemId';

  // Banners (promo beranda) ---------------------------------------------
  static const String banners = '/banners';
  static const String adminBanners = '/admin/banners';
  static const String adminBannerUpload = '/admin/banners/upload';
  static String banner(String id) => '/banners/$id';

  // Notifications -------------------------------------------------------
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String registerDevice = '/notifications/register-device';

  /// Timeout default (ms).
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 15000;
}
