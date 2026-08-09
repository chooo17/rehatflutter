import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../printer/application/printer_controller.dart';
import '../../../shared/widgets/qris_payment_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../review/presentation/review_sheet.dart';
import '../data/order_repository.dart';
import 'widgets/edit_order_sheet.dart';
import 'widgets/order_tracking_timeline.dart';
import 'widgets/reorder_button.dart';

/// Detail satu pesanan: item, status, ringkasan, dan pesan ulang.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final result = await ref.read(orderRepositoryProvider).reorder(id);
      ref.invalidate(orderHistoryProvider);
      router.pushReplacementNamed(RouteNames.confirmation, extra: result);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal memesan ulang.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Admin memakai endpoint admin (bisa lihat order pelanggan mana pun).
    final isAdmin = ref.watch(isAdminProvider);
    final detailAsync = isAdmin
        ? ref.watch(adminOrderDetailProvider(id))
        : ref.watch(orderDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(
              isAdmin ? adminOrderDetailProvider(id) : orderDetailProvider(id)),
        ),
        data: (order) => _Body(order: order, isAdmin: isAdmin),
      ),
      bottomNavigationBar: detailAsync.maybeWhen(
        // Admin tidak perlu tombol "Pesan Lagi" untuk order pelanggan.
        data: (order) => isAdmin
            ? null
            : Container(
                padding: EdgeInsets.fromLTRB(
                    20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _reorder(context, ref),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Pesan Lagi'),
                ),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order, this.isAdmin = false});
  final OrderModel order;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Header: nomor antrian + status.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.espresso,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.hasQueue ? 'Nomor antrian' : 'Status',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.crema.withValues(alpha: 0.7))),
                  const SizedBox(height: 2),
                  Text(order.queueLabel,
                      style: (order.hasQueue
                              ? AppTextStyles.displaySmall
                              : AppTextStyles.titleMedium)
                          .copyWith(color: AppColors.crema)),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.status.label,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.crema, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(Formatters.tanggalJam(order.createdAt),
            style: AppTextStyles.bodySmall),
        if (order.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.crema,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 18, color: AppColors.amberDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catatan untuk barista',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(order.notes, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Lacak Pesanan', style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),
        OrderTrackingTimeline(status: order.status),
        // Auto-refresh berkala selama pesanan berjalan (admin & pelanggan) →
        // status pembayaran (mis. QRIS lunas via webhook) tampil otomatis.
        _OrderAutoRefresh(
            orderId: order.id, status: order.status, isAdmin: isAdmin),
        _AdminStatusControls(order: order),
        if (order.status == OrderStatus.pending && !isAdmin) ...[
          const SizedBox(height: 20),
          QrisPaymentCard(orderId: order.id, amount: order.total),
        ],
        const SizedBox(height: 24),
        Text('Item', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        NeuCard(
          padding: EdgeInsets.zero,
          radius: 18,
          child: Column(
            children: [
              for (var i = 0; i < order.items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ItemRow(
                  item: order.items[i],
                  orderId: order.id,
                  canReview: order.status == OrderStatus.completed,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        NeuCard(
          padding: const EdgeInsets.all(16),
          radius: 18,
          child: Column(
            children: [
              _summaryRow('Tipe pesanan', order.orderType.label),
              if (order.tableNumber != null) ...[
                const SizedBox(height: 8),
                _summaryRow('Meja', order.tableNumber!),
              ],
              const SizedBox(height: 8),
              if (order.paymentMethod != null)
                _summaryRow('Pembayaran', order.paymentMethod!.toUpperCase()),
              if (order.subtotal > 0) ...[
                const SizedBox(height: 8),
                _summaryRow('Subtotal', Formatters.rupiah(order.subtotal)),
              ],
              if (order.discountAmount > 0) ...[
                const SizedBox(height: 8),
                _summaryRow('Diskon', '- ${Formatters.rupiah(order.discountAmount)}',
                    valueColor: AppColors.success),
              ],
              if (order.pointsEarned > 0) ...[
                const SizedBox(height: 8),
                _summaryRow('Poin didapat', '+${order.pointsEarned}',
                    valueColor: AppColors.amberDark),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  Text('Total', style: AppTextStyles.titleMedium),
                  const Spacer(),
                  Text(Formatters.rupiah(order.total),
                      style: AppTextStyles.titleLarge
                          .copyWith(color: AppColors.amberDark)),
                ],
              ),
            ],
          ),
        ),
        if (!isAdmin &&
            (order.status == OrderStatus.completed ||
                order.status == OrderStatus.cancelled)) ...[
          const SizedBox(height: 20),
          ReorderButton(order: order),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: AppTextStyles.bodyMedium
                .copyWith(color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.orderId,
    this.canReview = false,
  });
  final OrderItemModel item;
  final String orderId;
  final bool canReview;

  @override
  Widget build(BuildContext context) {
    final showReview = canReview && item.menuItemId.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.quantity}x',
                  style:
                      AppTextStyles.label.copyWith(color: AppColors.amberDark)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.bodyLarge),
                    if (item.customizationSummary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.customizationSummary,
                          style: AppTextStyles.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(Formatters.rupiah(item.subtotal),
                  style: AppTextStyles.bodyMedium),
            ],
          ),
          if (showReview)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('Beri ulasan'),
                onPressed: () => ReviewSheet.show(
                  context,
                  menuItemId: item.menuItemId,
                  orderId: orderId,
                  itemName: item.name,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kontrol status pesanan untuk admin (maju ke status berikutnya / batalkan).
/// Hanya tampil bila pengguna saat ini admin.
class _AdminStatusControls extends ConsumerStatefulWidget {
  const _AdminStatusControls({required this.order});
  final OrderModel order;

  @override
  ConsumerState<_AdminStatusControls> createState() =>
      _AdminStatusControlsState();
}

class _AdminStatusControlsState extends ConsumerState<_AdminStatusControls> {
  bool _busy = false;

  Future<void> _setStatus(OrderStatus status,
      {PaymentMethod? paymentMethod}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orderRepositoryProvider).updateStatus(widget.order.id, status,
          paymentMethod: paymentMethod);
      ref.invalidate(orderDetailProvider(widget.order.id));
      ref.invalidate(adminOrderDetailProvider(widget.order.id));
      ref.invalidate(orderHistoryProvider);
      ref.invalidate(adminOrdersProvider);
      // Saat selesai, poin/stamp bertambah di server — segarkan profil.
      if (status == OrderStatus.completed) {
        ref.read(authControllerProvider.notifier).refreshUser();
      }
      // Baru ditandai LUNAS → auto-cetak struk (ambil data terbaru + antrian).
      if (status == OrderStatus.paid) {
        try {
          final fresh = await ref
              .read(orderRepositoryProvider)
              .fetchDetailAdmin(widget.order.id);
          await ref
              .read(printerControllerProvider.notifier)
              .autoPrintOnce(fresh);
        } catch (_) {}
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Status: ${status.label}')));
    } catch (_) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Gagal memperbarui status.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Edit item pesanan tersimpan (tambah/hapus/ubah jumlah) via bottom sheet.
  Future<void> _editItems() async {
    final changed = await showEditOrderSheet(context, widget.order);
    if (!changed || !mounted) return;
    ref.invalidate(orderDetailProvider(widget.order.id));
    ref.invalidate(adminOrderDetailProvider(widget.order.id));
    ref.invalidate(pendingOrdersProvider);
    ref.invalidate(adminOrdersProvider);
  }

  /// Refund TUNAI penuh — dialog alasan wajib lalu panggil API.
  Future<void> _refund() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Refund Tunai'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kembalikan seluruh uang pesanan ini secara tunai. '
                  'Tindakan ini tidak bisa dibatalkan.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Alasan refund (wajib)',
                    hintText: 'mis. pesanan salah, pelanggan batal',
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.length < 3) {
                    setLocal(() => errorText = 'Alasan minimal 3 karakter');
                    return;
                  }
                  Navigator.of(ctx).pop(text);
                },
                child: const Text('Refund'),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orderRepositoryProvider).refundOrder(widget.order.id, reason);
      ref.invalidate(orderDetailProvider(widget.order.id));
      ref.invalidate(adminOrderDetailProvider(widget.order.id));
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(ordersTrackingProvider);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Pesanan di-refund.')));
    } on ApiException catch (e) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Gagal refund pesanan.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printReceipt() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(printerControllerProvider.notifier)
        .printOrder(widget.order);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(ok
              ? 'Struk dicetak.'
              : 'Gagal mencetak. Sambungkan printer di Profil → Printer & Struk.')));
  }

  /// Tampilkan QRIS pesanan (mis. pelanggan mau scan lagi) di bottom sheet.
  void _showQris() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pembayaran QRIS', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text('Nomor antrian keluar otomatis setelah pembayaran.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              QrisPaymentCard(
                  orderId: widget.order.id, amount: widget.order.total),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const SizedBox.shrink();

    final status = widget.order.status;
    final next = status.next;
    final isClosed =
        status == OrderStatus.completed || status == OrderStatus.cancelled;
    // Refund hanya untuk pesanan TUNAI yang sudah dibayar & belum di-refund/batal.
    final isCash = (widget.order.paymentMethod ?? '').toLowerCase() == 'cash';
    final canRefund = isCash &&
        (status == OrderStatus.paid ||
            status == OrderStatus.preparing ||
            status == OrderStatus.completed);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.crema,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined,
                  size: 18, color: AppColors.amberDark),
              const SizedBox(width: 8),
              Text('Kelola Status (Admin)', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 12),
          // Cetak struk (hanya Android; web tak mendukung printer thermal).
          if (ref.watch(printerControllerProvider).supported) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: ref.watch(printerControllerProvider).busy
                    ? null
                    : _printReceipt,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Cetak Struk'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.espresso,
                  side: BorderSide(color: AppColors.border),
                  minimumSize: const Size(0, 46),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.amber)),
              ),
            )
          else ...[
            // Pesanan menunggu bayar → customer bisa bayar QRIS (berlaku juga
            // untuk pesanan disimpan/bayar-nanti) ATAU kasir tandai lunas tunai.
            if (status == OrderStatus.pending) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _editItems,
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text('Edit item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.espresso,
                    side: BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showQris,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Tampilkan QRIS'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amberDark,
                    side: BorderSide(color: AppColors.amberDark),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _setStatus(OrderStatus.paid, paymentMethod: PaymentMethod.cash),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Lunas (Tunai)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (next != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _setStatus(next),
                      child: Text('Tandai ${next.label}'),
                    ),
                  ),
                if (next != null && !isClosed) const SizedBox(width: 10),
                if (!isClosed)
                  OutlinedButton(
                    onPressed: () => _setStatus(OrderStatus.cancelled),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.border),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Batalkan'),
                  ),
                if (isClosed)
                  Text('Pesanan ${status.label.toLowerCase()}.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
              ],
            ),
            // Refund tunai — pesanan sudah dibayar tunai & belum di-refund.
            if (canRefund) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _refund,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Refund (Tunai)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Menyegarkan detail pesanan secara berkala (invisible) selama pesanan masih
/// berjalan, agar pelanggan melihat perubahan status otomatis.
class _OrderAutoRefresh extends ConsumerStatefulWidget {
  const _OrderAutoRefresh(
      {required this.orderId, required this.status, this.isAdmin = false});
  final String orderId;
  final OrderStatus status;
  final bool isAdmin;

  @override
  ConsumerState<_OrderAutoRefresh> createState() => _OrderAutoRefreshState();
}

class _OrderAutoRefreshState extends ConsumerState<_OrderAutoRefresh> {
  Timer? _timer;

  static const _pollInterval = Duration(seconds: 7);

  bool get _isTerminal =>
      widget.status == OrderStatus.completed ||
      widget.status == OrderStatus.cancelled;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _OrderAutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Status berubah (provider ter-refresh) → jadwalkan ulang.
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_isTerminal) return;
    _timer = Timer(_pollInterval, () {
      if (!mounted) return;
      if (widget.isAdmin) {
        ref.invalidate(adminOrderDetailProvider(widget.orderId));
      } else {
        ref.invalidate(orderDetailProvider(widget.orderId));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text('Gagal memuat detail pesanan.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
