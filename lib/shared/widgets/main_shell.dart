import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/responsive.dart';
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
    final body = Stack(
      children: [
        navigationShell,
        const NotificationPoller(),
      ],
    );

    // Layar lebar (≥1024, desktop & iPad lanskap): navigasi pindah ke sidebar
    // kiri — pola adaptif Material — sehingga isi memakai sisa lebar penuh
    // tanpa ruang kosong di kiri-kanan. MediaQuery isi di-override ke lebar
    // sisanya agar perhitungan kolom di tiap layar membaca ruang yang benar.
    if (context.isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SideNav(
              tabs: tabs,
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final mq = MediaQuery.of(context);
                  final theme = Theme.of(context);
                  return MediaQuery(
                    data: mq.copyWith(size: Size(c.maxWidth, mq.size.height)),
                    // Judul app bar sejajar dgn padding isi layar lebar (32).
                    child: Theme(
                      data: theme.copyWith(
                        appBarTheme:
                            theme.appBarTheme.copyWith(titleSpacing: 32),
                      ),
                      child: body,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: body,
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

/// Sidebar navigasi untuk layar lebar: logo + item ikon+label. Gaya sama dgn
/// pill bawah (surface, border tipis, pill krem untuk tab aktif).
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_Tab> tabs;
  final int currentIndex;
  final void Function(int branch) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.espresso,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_cafe_rounded,
                        color: AppColors.amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Rehat\nCoffeehouse',
                        style: AppTextStyles.titleMedium.copyWith(height: 1.15)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              for (final t in tabs) ...[
                _SideNavItem(
                  icon: t.icon,
                  selectedIcon: t.selectedIcon,
                  label: t.label,
                  selected: currentIndex == t.branch,
                  onTap: () => onTap(t.branch),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
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
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? AppColors.amberDark : AppColors.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.crema
                : (_hover
                    ? AppColors.crema.withValues(alpha: 0.5)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(selected ? widget.selectedIcon : widget.icon,
                  size: 22, color: color),
              const SizedBox(width: 14),
              Text(
                widget.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected ? AppColors.textPrimary : color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
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
