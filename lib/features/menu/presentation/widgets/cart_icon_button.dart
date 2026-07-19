import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/widgets/cart_fly.dart';
import '../../../../shared/widgets/neu.dart';
import '../../application/cart_controller.dart';

/// Ikon keranjang dengan badge jumlah item. Mengarah ke layar keranjang.
///
/// Ikonnya juga menjadi **target** animasi "lempar ke keranjang" (mendaftarkan
/// [GlobalKey]-nya), dan badge-nya **memantul** saat jumlah item bertambah.
class CartIconButton extends ConsumerStatefulWidget {
  const CartIconButton({super.key, this.color});

  final Color? color;

  @override
  ConsumerState<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends ConsumerState<CartIconButton>
    with SingleTickerProviderStateMixin {
  final GlobalKey _iconKey = GlobalKey();
  late final AnimationController _bounce;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.45)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.45, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_bounce);
    registerCartTarget(_iconKey);
  }

  @override
  void dispose() {
    unregisterCartTarget(_iconKey);
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pantulkan badge tiap kali jumlah item bertambah.
    ref.listen<int>(cartCountProvider, (prev, next) {
      if (next > (prev ?? 0)) _bounce.forward(from: 0);
    });
    final count = ref.watch(cartCountProvider);

    return Semantics(
      button: true,
      label: count > 0 ? 'Keranjang, $count item' : 'Keranjang',
      child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          KeyedSubtree(
            key: _iconKey,
            child: NeuCircleButton(
              icon: Icons.shopping_bag_outlined,
              iconColor: widget.color,
              onPressed: () => context.pushNamed(RouteNames.cart),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: ScaleTransition(
                scale: _badgeScale,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.backgroundLight, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.espresso,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
