import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/neu.dart';
import '../../application/reorder_service.dart';

/// Tombol "Pesan Lagi": mengisi ulang keranjang dari pesanan lama lalu
/// mengarahkan ke keranjang. Tampil sebagai tombol penuh atau ringkas.
class ReorderButton extends ConsumerStatefulWidget {
  const ReorderButton({super.key, required this.order, this.compact = false});

  final OrderModel order;

  /// Bila true, tampil sebagai [OutlinedButton] ringkas (untuk kartu riwayat).
  final bool compact;

  @override
  ConsumerState<ReorderButton> createState() => _ReorderButtonState();
}

class _ReorderButtonState extends ConsumerState<ReorderButton> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final result =
          await ref.read(reorderServiceProvider).addOrderToCart(widget.order);

      if (!mounted) return;
      if (!result.hasAdded) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Item pesanan ini sudah tidak tersedia.'),
          ));
        return;
      }

      final msg = result.hasSkipped
          ? '${result.added} item masuk keranjang. ${result.skipped.length} item tidak tersedia.'
          : '${result.added} item ditambahkan ke keranjang.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      router.pushNamed(RouteNames.cart);
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Gagal memesan ulang. Coba lagi.'),
        ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
          )
        : const Icon(Icons.replay_rounded, size: 18);
    final onPressed = _loading ? null : _run;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Text('Pesan Lagi',
            style: AppTextStyles.button.copyWith(color: AppColors.textPrimary)),
      ],
    );

    return NeuButton(
      onPressed: onPressed,
      expand: !widget.compact,
      radius: 14,
      padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 16 : 20, vertical: 12),
      child: label,
    );
  }
}
