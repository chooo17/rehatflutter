/// Nama & path rute aplikasi (terpusat agar mudah dirujuk).
class RouteNames {
  RouteNames._();

  static const String splash = 'splash';
  static const String splashPath = '/splash';

  static const String login = 'login';
  static const String loginPath = '/login';

  static const String register = 'register';
  static const String registerPath = '/register';

  static const String otp = 'otp';
  static const String otpPath = '/otp';

  static const String profileSetup = 'profile-setup';
  static const String profileSetupPath = '/profile-setup';

  static const String home = 'home';
  static const String homePath = '/home';

  static const String menu = 'menu';
  static const String menuPath = '/menu';

  /// Tab Laporan penjualan (admin) di bottom navigation.
  static const String report = 'report';
  static const String reportPath = '/report';

  /// Menu untuk tamu (tanpa login) — hanya lihat menu.
  static const String guestMenu = 'guest-menu';
  static const String guestMenuPath = '/guest-menu';

  static const String menuDetail = 'menu-detail';
  static const String menuDetailPath = '/menu/detail/:id';

  static const String cart = 'cart';
  static const String cartPath = '/cart';

  static const String checkout = 'checkout';
  static const String checkoutPath = '/checkout';

  static const String confirmation = 'confirmation';
  static const String confirmationPath = '/order/confirmation';

  static const String orderHistory = 'order-history';
  static const String orderHistoryPath = '/profile/orders';

  static const String orderDetail = 'order-detail';
  static const String orderDetailPath = '/profile/order-detail/:id';

  static const String spin = 'spin';
  static const String spinPath = '/spin';

  static const String loyalty = 'loyalty';
  static const String loyaltyPath = '/loyalty';

  static const String loyaltyHistory = 'loyalty-history';
  static const String loyaltyHistoryPath = '/loyalty/history';

  static const String profile = 'profile';
  static const String profilePath = '/profile';

  static const String editProfile = 'edit-profile';
  static const String editProfilePath = '/profile/edit';

  static const String favorites = 'favorites';
  static const String favoritesPath = '/favorites';

  static const String notifications = 'notifications';
  static const String notificationsPath = '/notifications';

  static const String help = 'help';
  static const String helpPath = '/profile/help';

  static const String adminMenuImages = 'admin-menu-images';
  static const String adminMenuImagesPath = '/profile/admin-menu-images';

  static const String orderTracking = 'order-tracking';
  static const String orderTrackingPath = '/profile/order-tracking';

  static const String adminMenuCost = 'admin-menu-cost';
  static const String adminMenuCostPath = '/profile/admin-menu-cost';

  static const String freeDrinkRedeem = 'free-drink-redeem';
  static const String freeDrinkRedeemPath = '/profile/free-drink-redeem';

  static const String adminMenuManage = 'admin-menu-manage';
  static const String adminMenuManagePath = '/profile/admin-menu-manage';

  static const String adminQrTables = 'admin-qr-tables';
  static const String adminQrTablesPath = '/profile/admin-qr-tables';

  static const String closingReport = 'closing-report';
  static const String closingReportPath = '/profile/closing-report';

  static const String customerSegments = 'customer-segments';
  static const String customerSegmentsPath = '/profile/customer-segments';

  static const String adminAnalytics = 'admin-analytics';
  static const String adminAnalyticsPath = '/profile/admin-analytics';

  static const String wallet = 'wallet';
  static const String walletPath = '/profile/wallet';

  static const String referral = 'referral';
  static const String referralPath = '/profile/referral';

  static const String adminOrders = 'admin-orders';
  static const String adminOrdersPath = '/profile/admin-orders';

  static const String adminBanners = 'admin-banners';
  static const String adminBannersPath = '/profile/admin-banners';

  static const String adminDashboard = 'admin-dashboard';
  static const String adminDashboardPath = '/profile/admin-dashboard';

  static const String savedOrders = 'saved-orders';
  static const String savedOrdersPath = '/profile/saved-orders';

  static const String printerSettings = 'printer-settings';
  static const String printerSettingsPath = '/profile/printer-settings';
}
