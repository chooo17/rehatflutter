import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
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
    final isAdmin = ref.watch(authControllerProvider).user?.isAdmin ?? false;
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
      bottomNavigationBar: Neumorphic(
        style: NeumorphicStyle(
          depth: 14,
          intensity: 0.82,
          boxShape: NeumorphicBoxShape.roundRect(
            const BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }
}

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = selected ? AppColors.amberDark : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Neumorphic(
            duration: const Duration(milliseconds: 200),
            style: NeumorphicStyle(
              depth: selected ? -6 : 4,
              intensity: 0.85,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            child: Icon(selected ? selectedIcon : icon, size: 22, color: color),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
