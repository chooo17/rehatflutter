import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/notifications/presentation/widgets/notification_poller.dart';

/// Satu entri tab: indeks CABANG di StatefulShellRoute + ikon + label.
typedef _Tab = ({int branch, IconData icon, IconData selectedIcon, String label});

/// Kerangka utama dengan bottom navigation neumorphic.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int branch) {
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // isAdmin sudah otomatis false pada build "customer" (lihat UserModel).
    final isAdmin = ref.watch(isAdminProvider);
    // Urutan cabang di router: 0 Beranda, 1 Menu, 2 Loyalti, 3 Profil, 4 Laporan.
    final tabs = <_Tab>[
      (branch: 0, icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Beranda'),
      (branch: 1, icon: Icons.local_cafe_outlined, selectedIcon: Icons.local_cafe_rounded, label: 'Menu'),
      (branch: 2, icon: Icons.card_giftcard_outlined, selectedIcon: Icons.card_giftcard_rounded, label: 'Loyalti'),
      if (isAdmin)
        (branch: 4, icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'Laporan'),
      (branch: 3, icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profil'),
    ];
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          navigationShell,
          const NotificationPoller(),
        ],
      ),
      // Navbar mengambang: pill dengan margin di kiri/kanan/bawah + bayangan
      // lembut agar terasa "melayang" di atas konten.
      bottomNavigationBar: SafeArea(
        top: false,
        // heightFactor: 1 — Center polos memuai setinggi layar di
        // bottomNavigationBar, menelan seluruh body (konten jadi kosong).
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.espresso.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (final t in tabs)
                    Expanded(
                      child: _NavItem(
                        icon: t.icon,
                        selectedIcon: t.selectedIcon,
                        label: t.label,
                        selected: navigationShell.currentIndex == t.branch,
                        onTap: () => _onTap(t.branch),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? AppColors.amberDark : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick(); // getar halus saat pindah tab
        widget.onTap();
      },
      // Micro-interaction: seluruh tab mengecil sedikit saat ditekan.
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Pill" aktif membesar mulus; ikon berganti dgn transisi scale+fade.
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                  horizontal: selected ? 22 : 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.crema : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  selected ? widget.selectedIcon : widget.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}
