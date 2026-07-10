import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/widgets/neu.dart';
import '../../data/notification_repository.dart';

/// Ikon lonceng dengan badge jumlah notifikasi belum dibaca.
class NotificationIconButton extends ConsumerWidget {
  const NotificationIconButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          NeuCircleButton(
            icon: Icons.notifications_none_rounded,
            iconColor: color,
            onPressed: () => context.pushNamed(RouteNames.notifications),
          ),
          if (unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.backgroundLight, width: 1.5),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
