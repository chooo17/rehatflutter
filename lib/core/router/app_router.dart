import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics_service.dart';

import '../../features/admin/presentation/admin_banners_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/saved_orders_screen.dart';
import '../../features/printer/presentation/printer_settings_screen.dart';
import '../../features/admin/presentation/admin_menu_images_screen.dart';
import '../../features/admin/presentation/admin_menu_cost_screen.dart';
import '../../features/admin/presentation/admin_menu_manage_screen.dart';
import '../../features/admin/presentation/admin_qr_tables_screen.dart';
import '../../features/loyalty/presentation/free_drink_redeem_screen.dart';
import '../../features/admin/presentation/closing_report_screen.dart';
import '../../features/admin/presentation/customer_segments_screen.dart';
import '../../features/admin/presentation/admin_analytics_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/wallet/presentation/referral_screen.dart';
import '../../features/admin/presentation/admin_orders_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/loyalty/presentation/loyalty_history_screen.dart';
import '../../features/loyalty/presentation/loyalty_screen.dart';
import '../../features/menu/presentation/cart_screen.dart';
import '../../features/menu/presentation/menu_detail_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/order/application/checkout_controller.dart';
import '../../features/order/presentation/checkout_screen.dart';
import '../../features/order/presentation/order_confirmation_screen.dart';
import '../../features/order/presentation/order_detail_screen.dart';
import '../../features/order/presentation/order_history_screen.dart';
import '../../features/order/presentation/order_tracking_screen.dart';
import '../../shared/models/order_model.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/help_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/spin/presentation/spin_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../shared/widgets/splash_screen.dart';
import 'route_names.dart';

/// Provider [GoRouter] dengan redirect berbasis status autentikasi.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: RouteNames.splashPath,
    refreshListenable: refresh,
    // Lacak screen_view otomatis bila analitik aktif (mobile). No-op di web.
    observers: [
      if (Analytics.instance != null)
        FirebaseAnalyticsObserver(analytics: Analytics.instance!),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      final onSplash = loc == RouteNames.splashPath;
      // Halaman alur masuk yang boleh diakses tanpa sesi (termasuk OTP,
      // karena register belum menghasilkan token sampai OTP diverifikasi).
      final onAuthFlow = loc == RouteNames.loginPath ||
          loc == RouteNames.registerPath ||
          loc == RouteNames.otpPath ||
          loc == RouteNames.forgotPasswordPath ||
          loc == RouteNames.resetPasswordPath;

      // Sesi belum dipulihkan — tahan di splash.
      if (auth.status == AuthStatus.unknown) {
        return onSplash ? null : RouteNames.splashPath;
      }

      // Mode tamu: boleh menu, detail, keranjang, checkout, konfirmasi, dan
      // alur login. Fitur berakun lain (beranda/loyalti/profil) tetap terkunci.
      if (auth.status == AuthStatus.guest) {
        final guestAllowed = loc == RouteNames.guestMenuPath ||
            loc.startsWith('/menu/detail') ||
            loc == RouteNames.cartPath ||
            loc == RouteNames.checkoutPath ||
            loc == RouteNames.confirmationPath ||
            onAuthFlow;
        return guestAllowed ? null : RouteNames.guestMenuPath;
      }

      final loggedIn = auth.status == AuthStatus.authenticated;

      if (!loggedIn) {
        // Belum masuk: hanya boleh di halaman alur masuk.
        return onAuthFlow ? null : RouteNames.loginPath;
      }

      // Sudah masuk tapi profil belum lengkap → wajib lengkapi profil dulu.
      final needsProfile = !auth.isProfileComplete;
      final onProfileSetup = loc == RouteNames.profileSetupPath;
      if (needsProfile) {
        return onProfileSetup ? null : RouteNames.profileSetupPath;
      }

      // Profil lengkap: jauhkan dari splash/auth/profile-setup.
      if (onSplash || onAuthFlow || onProfileSetup) return RouteNames.homePath;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.registerPath,
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.otpPath,
        name: RouteNames.otp,
        builder: (context, state) {
          final args = (state.extra as Map?) ?? const {};
          return OtpScreen(
            otpToken: (args['otpToken'] ?? '').toString(),
            phone: (args['phone'] ?? '').toString(),
            otpSent: (args['otpSent'] ?? true) == true,
          );
        },
      ),
      GoRoute(
        path: RouteNames.forgotPasswordPath,
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.resetPasswordPath,
        name: RouteNames.resetPassword,
        builder: (context, state) {
          final args = (state.extra as Map?) ?? const {};
          return ResetPasswordScreen(
            otpToken: (args['otpToken'] ?? '').toString(),
            phone: (args['phone'] ?? '').toString(),
            otpSent: (args['otpSent'] ?? true) == true,
          );
        },
      ),
      GoRoute(
        path: RouteNames.profileSetupPath,
        name: RouteNames.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      // Menu tamu (tanpa login) — memakai MenuScreen dalam mode guest.
      GoRoute(
        path: RouteNames.guestMenuPath,
        name: RouteNames.guestMenu,
        builder: (context, state) => const MenuScreen(),
      ),
      GoRoute(
        path: RouteNames.spinPath,
        name: RouteNames.spin,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const SpinScreen(),
      ),
      GoRoute(
        path: RouteNames.menuDetailPath,
        name: RouteNames.menuDetail,
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            MenuDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RouteNames.cartPath,
        name: RouteNames.cart,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: RouteNames.checkoutPath,
        name: RouteNames.checkout,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: RouteNames.confirmationPath,
        name: RouteNames.confirmation,
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          // `extra` bisa hilang saat router refresh — pakai provider sebagai
          // sumber utama, dengan `extra` sebagai cadangan.
          final extra = state.extra;
          final result = extra is CheckoutResult
              ? extra
              : ref.read(lastCheckoutResultProvider);
          if (result == null) return const OrderHistoryScreen();
          return OrderConfirmationScreen(result: result);
        },
      ),
      GoRoute(
        path: RouteNames.favoritesPath,
        name: RouteNames.favorites,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: RouteNames.notificationsPath,
        name: RouteNames.notifications,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Shell dengan bottom navigation.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: shellKey,
            routes: [
              GoRoute(
                path: RouteNames.homePath,
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.menuPath,
                name: RouteNames.menu,
                builder: (context, state) => const MenuScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.loyaltyPath,
                name: RouteNames.loyalty,
                builder: (context, state) => const LoyaltyScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    name: RouteNames.loyaltyHistory,
                    builder: (context, state) => const LoyaltyHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profilePath,
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: RouteNames.editProfile,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'help',
                    name: RouteNames.help,
                    builder: (context, state) => const HelpScreen(),
                  ),
                  GoRoute(
                    path: 'orders',
                    name: RouteNames.orderHistory,
                    builder: (context, state) => const OrderHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'order-detail/:id',
                    name: RouteNames.orderDetail,
                    builder: (context, state) =>
                        OrderDetailScreen(id: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'admin-menu-images',
                    name: RouteNames.adminMenuImages,
                    builder: (context, state) => const AdminMenuImagesScreen(),
                  ),
                  GoRoute(
                    path: 'order-tracking',
                    name: RouteNames.orderTracking,
                    builder: (context, state) => const OrderTrackingScreen(),
                  ),
                  GoRoute(
                    path: 'admin-menu-cost',
                    name: RouteNames.adminMenuCost,
                    builder: (context, state) => const AdminMenuCostScreen(),
                  ),
                  GoRoute(
                    path: 'free-drink-redeem',
                    name: RouteNames.freeDrinkRedeem,
                    builder: (context, state) => const FreeDrinkRedeemScreen(),
                  ),
                  GoRoute(
                    path: 'admin-menu-manage',
                    name: RouteNames.adminMenuManage,
                    builder: (context, state) => const AdminMenuManageScreen(),
                  ),
                  GoRoute(
                    path: 'admin-qr-tables',
                    name: RouteNames.adminQrTables,
                    builder: (context, state) => const AdminQrTablesScreen(),
                  ),
                  GoRoute(
                    path: 'closing-report',
                    name: RouteNames.closingReport,
                    builder: (context, state) => const ClosingReportScreen(),
                  ),
                  GoRoute(
                    path: 'customer-segments',
                    name: RouteNames.customerSegments,
                    builder: (context, state) => const CustomerSegmentsScreen(),
                  ),
                  GoRoute(
                    path: 'admin-analytics',
                    name: RouteNames.adminAnalytics,
                    builder: (context, state) => const AdminAnalyticsScreen(),
                  ),
                  GoRoute(
                    path: 'wallet',
                    name: RouteNames.wallet,
                    builder: (context, state) => const WalletScreen(),
                  ),
                  GoRoute(
                    path: 'referral',
                    name: RouteNames.referral,
                    builder: (context, state) => const ReferralScreen(),
                  ),
                  GoRoute(
                    path: 'admin-orders',
                    name: RouteNames.adminOrders,
                    builder: (context, state) => const AdminOrdersScreen(),
                  ),
                  GoRoute(
                    path: 'admin-banners',
                    name: RouteNames.adminBanners,
                    builder: (context, state) => const AdminBannersScreen(),
                  ),
                  GoRoute(
                    path: 'admin-dashboard',
                    name: RouteNames.adminDashboard,
                    builder: (context, state) => const AdminDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'saved-orders',
                    name: RouteNames.savedOrders,
                    builder: (context, state) => const SavedOrdersScreen(),
                  ),
                  GoRoute(
                    path: 'printer-settings',
                    name: RouteNames.printerSettings,
                    builder: (context, state) => const PrinterSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Cabang ke-5 (index 4): tab Laporan — hanya tampil untuk admin.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.reportPath,
                name: RouteNames.report,
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Menjembatani perubahan [AuthState] ke [GoRouter.refreshListenable].
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
