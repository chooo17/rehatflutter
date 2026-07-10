import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/widgets/neu.dart';
import '../application/cart_controller.dart';

/// Keranjang belanja: daftar item, ubah jumlah, ringkasan & checkout.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartControllerProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: const Text('Kosongkan'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyCart()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 28),
              itemBuilder: (context, i) => _CartLine(line: items[i]),
            ),
      bottomNavigationBar:
          items.isEmpty ? null : _CheckoutBar(total: total, count: items.length),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kosongkan keranjang', style: AppTextStyles.headline),
        content: Text('Hapus semua item dari keranjang?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: AppTextStyles.label.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (yes == true) ref.read(cartControllerProvider.notifier).clear();
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.line});
  final CartItemModel line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartControllerProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 72,
            height: 72,
            child: _Thumb(url: line.item.imageUrl),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(line.item.name,
                        style: AppTextStyles.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: () => cart.remove(line.lineId),
                    child: Icon(Icons.delete_outline_rounded,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ],
              ),
              if (line.customizationSummary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(line.customizationSummary,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(Formatters.rupiah(line.subtotal),
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.amberDark)),
                  const Spacer(),
                  _MiniStepper(
                    quantity: line.quantity,
                    onDecrement: () => cart.decrement(line.lineId),
                    onIncrement: () => cart.increment(line.lineId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return NeuInset(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      radius: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, onDecrement),
          SizedBox(
            width: 30,
            child: Text('$quantity',
                textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
          ),
          _btn(Icons.add_rounded, onIncrement),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: AppColors.espresso),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total, required this.count});
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return NeuBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Total ($count item)',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text(Formatters.rupiah(total), style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          NeuButton(
            expand: true,
            accent: true,
            onPressed: () => context.pushNamed(RouteNames.checkout),
            child: Text('Lanjut ke Pembayaran',
                style: AppTextStyles.button.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.crema,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.shopping_bag_outlined,
                color: AppColors.amberDark, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Keranjang masih kosong', style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text('Yuk pilih kopi favoritmu dari menu.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.goNamed(RouteNames.menu),
            child: const Text('Lihat Menu'),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: AppColors.crema,
        child: const Icon(Icons.local_cafe_rounded,
            color: AppColors.amber, size: 28),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.crema),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.crema,
        child: const Icon(Icons.local_cafe_rounded,
            color: AppColors.amber, size: 28),
      ),
    );
  }
}
