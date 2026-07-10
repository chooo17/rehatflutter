import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/notifications/presentation/widgets/notification_poller.dart';

/// Kerangka utama dengan bottom navigation neumorphic.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.local_cafe_outlined, Icons.local_cafe_rounded, 'Menu'),
    (Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, 'Loyalti'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _items[i].$1,
                      selectedIcon: _items[i].$2,
                      label: _items[i].$3,
                      selected: navigationShell.currentIndex == i,
                      onTap: () => _onTap(i),
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
