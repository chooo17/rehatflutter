import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/neu.dart';
import '../../auth/application/auth_controller.dart';

/// Profil pengguna & pengaturan.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              NeuCard(
                padding: EdgeInsets.zero,
                radius: 20,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              color: AppColors.amberDark,
                              size: 32),
                        )
                      : Icon(Icons.person_rounded,
                          color: AppColors.amberDark, size: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name.isNotEmpty == true
                          ? user!.name
                          : 'Sahabat Rehat',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.phone ?? '-',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _tile(Icons.person_outline_rounded, 'Edit profil',
              onTap: () => context.pushNamed(RouteNames.editProfile)),
          _tile(Icons.account_balance_wallet_outlined, 'Saldo Saya',
              onTap: () => context.pushNamed(RouteNames.wallet)),
          _tile(Icons.card_giftcard_outlined, 'Ajak Teman',
              onTap: () => context.pushNamed(RouteNames.referral)),
          _tile(Icons.receipt_long_outlined, 'Riwayat pesanan',
              onTap: () => context.pushNamed(RouteNames.orderHistory)),
          _tile(Icons.local_offer_outlined, 'Voucher saya',
              onTap: () => context.goNamed(RouteNames.loyalty)),
          _tile(Icons.notifications_none_rounded, 'Notifikasi',
              onTap: () => context.pushNamed(RouteNames.notifications)),
          _tile(Icons.help_outline_rounded, 'Bantuan',
              onTap: () => context.pushNamed(RouteNames.help)),
          if (user?.isAdmin == true) ...[
            _tile(Icons.insights_rounded, 'Dashboard Penjualan',
                onTap: () => context.pushNamed(RouteNames.adminDashboard)),
            _tile(Icons.query_stats_rounded, 'Analitik',
                onTap: () => context.pushNamed(RouteNames.adminAnalytics)),
            _tile(Icons.point_of_sale_rounded, 'Tutup Kasir',
                onTap: () => context.pushNamed(RouteNames.closingReport)),
            _tile(Icons.receipt_long_rounded, 'Pesanan Masuk (Admin)',
                onTap: () => context.pushNamed(RouteNames.adminOrders)),
            _tile(Icons.groups_rounded, 'Segmen Pelanggan',
                onTap: () => context.pushNamed(RouteNames.customerSegments)),
            _tile(Icons.inventory_2_outlined, 'HPP & Margin Menu',
                onTap: () => context.pushNamed(RouteNames.adminMenuCost)),
            _tile(Icons.admin_panel_settings_outlined, 'Kelola Gambar Menu',
                onTap: () => context.pushNamed(RouteNames.adminMenuImages)),
            _tile(Icons.campaign_outlined, 'Kelola Banner',
                onTap: () => context.pushNamed(RouteNames.adminBanners)),
            _tile(Icons.print_rounded, 'Printer & Struk',
                onTap: () => context.pushNamed(RouteNames.printerSettings)),
          ],
          const SizedBox(height: 24),
          Text('Tampilan', style: AppTextStyles.titleMedium),
          const SizedBox(height: 10),
          _ThemeModeSelector(
            mode: ref.watch(themeModeControllerProvider),
            onChanged: (m) =>
                ref.read(themeModeControllerProvider.notifier).setMode(m),
          ),
          const SizedBox(height: 24),
          NeuButton(
            expand: true,
            onPressed: () => _confirmLogout(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text('Keluar',
                    style: AppTextStyles.button.copyWith(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Baris menu: tiap item adalah kartu neumorphic timbul dengan depth &
  /// efek tekan sendiri.
  Widget _tile(IconData icon, String label, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        onTap: onTap ?? () {},
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        radius: 16,
        child: Row(
          children: [
            NeuInset(
              padding: EdgeInsets.zero,
              radius: 11,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(icon, color: AppColors.amberDark, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Keluar', style: AppTextStyles.headline),
        content: Text('Yakin ingin keluar dari akun?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Keluar',
                style: AppTextStyles.label.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(authControllerProvider.notifier).logout();
      // Redirect router akan otomatis mengarahkan ke halaman login.
    }
  }
}

/// Pemilih mode tema: Sistem / Terang / Gelap.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (ThemeMode.system, 'Sistem', Icons.brightness_auto_rounded),
    (ThemeMode.light, 'Terang', Icons.light_mode_rounded),
    (ThemeMode.dark, 'Gelap', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return NeuInset(
      padding: const EdgeInsets.all(6),
      radius: 16,
      child: Row(
        children: [
          for (final (m, label, icon) in _options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: NeuButton(
                  onPressed: () => onChanged(m),
                  accent: m == mode,
                  radius: 11,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Icon(icon,
                          size: 20,
                          color: m == mode
                              ? Colors.white
                              : AppColors.textSecondary),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppTextStyles.caption.copyWith(
                          color: m == mode
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
