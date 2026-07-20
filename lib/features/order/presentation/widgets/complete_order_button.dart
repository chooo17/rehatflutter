import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/order_model.dart';
import '../../data/order_repository.dart';

/// Tombol **Tandai Selesai** — memajukan pesanan aktif langsung ke `completed`.
///
/// Tidak ada lagi tombol "Tandai Diproses": begitu pembayaran diterima, backend
/// otomatis menaruh pesanan di status *Diproses*. Jadi satu-satunya aksi manual
/// yang tersisa untuk staf adalah menyelesaikan pesanan.
///
/// Dipakai bersama oleh layar **Pesanan Masuk** dan **kartu lacak pesanan**
/// supaya perilaku & tampilannya selaras.
class CompleteOrderButton extends ConsumerStatefulWidget {
  const CompleteOrderButton({
    super.key,
    required this.order,
    this.compact = false,
  });

  final OrderModel order;

  /// Versi ringkas (untuk kartu lacak) — lebih pendek & tanpa lebar penuh.
  final bool compact;

  @override
  ConsumerState<CompleteOrderButton> createState() =>
      _CompleteOrderButtonState();
}

class _CompleteOrderButtonState extends ConsumerState<CompleteOrderButton> {
  bool _busy = false;

  Future<void> _complete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(orderRepositoryProvider)
          .updateStatus(widget.order.id, OrderStatus.completed);
      // Segarkan semua tampilan yang menampilkan pesanan ini.
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminOrderDetailProvider(widget.order.id));
      ref.invalidate(ordersTrackingProvider);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Pesanan ditandai selesai')));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui status.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hanya untuk pesanan yang masih berjalan.
    if (!kActiveOrderStatuses.contains(widget.order.status)) {
      return const SizedBox.shrink();
    }
    final icon = _busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.check_rounded, size: 18);
    final label = Text(_busy ? 'Memproses…' : 'Tandai Selesai');
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.espresso,
      foregroundColor: AppColors.crema,
      minimumSize: Size(0, widget.compact ? 38 : 44),
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 16),
    );

    final btn = ElevatedButton.icon(
      onPressed: _busy ? null : _complete,
      icon: icon,
      label: label,
      style: style,
    );
    return widget.compact ? btn : SizedBox(width: double.infinity, child: btn);
  }
}
