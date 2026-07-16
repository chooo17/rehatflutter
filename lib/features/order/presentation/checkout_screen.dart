import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../auth/application/auth_controller.dart';
import '../../menu/application/cart_controller.dart';
import '../application/checkout_controller.dart';

/// Metode pembayaran yang tampil untuk pelanggan (tanpa 'cash' = kasir saja).
final _customerMethods =
    PaymentMethod.values.where((m) => m != PaymentMethod.cash).toList();

/// Checkout: pilih metode pembayaran, terapkan voucher, lalu buat pesanan.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _voucherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();

  @override
  void dispose() {
    _voucherCtrl.dispose();
    _notesCtrl.dispose();
    _guestNameCtrl.dispose();
    _guestPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    FocusScope.of(context).unfocus();
    final isGuest = ref.read(authControllerProvider).isGuest;
    final result =
        await ref.read(checkoutControllerProvider.notifier).placeOrder(
              guestName: isGuest ? _guestNameCtrl.text : null,
              guestPhone: isGuest ? _guestPhoneCtrl.text : null,
            );
    if (!mounted) return;
    if (result != null) {
      context.pushReplacementNamed(RouteNames.confirmation, extra: result);
    } else {
      final msg = ref.read(checkoutControllerProvider).errorMessage ??
          'Gagal membuat pesanan.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _applyVoucher() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(checkoutControllerProvider.notifier)
        .applyVoucher(_voucherCtrl.text);
    if (!mounted) return;
    final st = ref.read(checkoutControllerProvider);
    if (st.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(st.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartControllerProvider);
    final subtotal = ref.watch(cartTotalProvider);
    final state = ref.watch(checkoutControllerProvider);
    final notifier = ref.read(checkoutControllerProvider.notifier);
    final isGuest = ref.watch(authControllerProvider).isGuest;
    final discount = state.discountAmount;
    final total = subtotal - discount;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: items.isEmpty
          ? Center(
              child: Text('Keranjang kosong.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (isGuest) ...[
                  const _SectionLabel('Data pemesan'),
                  const SizedBox(height: 10),
                  _GuestField(
                      controller: _guestNameCtrl,
                      hint: 'Nama kamu *',
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 10),
                  _GuestField(
                      controller: _guestPhoneCtrl,
                      hint: 'No. HP / WhatsApp (opsional)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 24),
                ],
                const _SectionLabel('Tipe pesanan'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final type in OrderType.values) ...[
                      Expanded(
                        child: _OrderTypeCard(
                          type: type,
                          selected: state.orderType == type,
                          onTap: () => notifier.setOrderType(type),
                        ),
                      ),
                      if (type != OrderType.values.last)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Metode pembayaran'),
                const SizedBox(height: 10),
                // 'cash' hanya untuk kasir (admin) — sembunyikan dari pelanggan.
                for (final method in _customerMethods) ...[
                  _PaymentRow(
                    method: method,
                    selected: state.paymentMethod == method,
                    onTap: () => notifier.setPaymentMethod(method),
                  ),
                  if (method != _customerMethods.last)
                    const SizedBox(height: 8),
                ],
                const SizedBox(height: 24),
                // Voucher tak berlaku untuk tamu (butuh akun).
                if (!isGuest) ...[
                  const _SectionLabel('Kode voucher'),
                  const SizedBox(height: 10),
                  _VoucherField(
                    controller: _voucherCtrl,
                    applied: state.voucher?.isValid == true,
                    isLoading: state.isValidatingVoucher,
                    onApply: _applyVoucher,
                    onClear: () {
                      _voucherCtrl.clear();
                      notifier.clearVoucher();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                const _SectionLabel('Catatan untuk barista'),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  onChanged: notifier.setNotes,
                  maxLines: 3,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Mis. es sedikit, gula 50%, nama di gelas: Rizki',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                const _SectionLabel('Ringkasan pesanan'),
                const SizedBox(height: 10),
                NeuCard(
                  padding: const EdgeInsets.all(16),
                  radius: 18,
                  child: Column(
                    children: [
                      for (final line in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${line.quantity}x',
                                  style: AppTextStyles.label
                                      .copyWith(color: AppColors.amberDark)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(line.item.name,
                                        style: AppTextStyles.bodyMedium),
                                    if (line.customizationSummary.isNotEmpty)
                                      Text(line.customizationSummary,
                                          style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ),
                              Text(Formatters.rupiah(line.subtotal),
                                  style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                      const Divider(height: 24),
                      _summaryRow('Subtotal', Formatters.rupiah(subtotal)),
                      if (discount > 0) ...[
                        const SizedBox(height: 6),
                        _summaryRow(
                          'Diskon voucher (${state.voucher!.discountPct}%)',
                          '- ${Formatters.rupiah(discount)}',
                          valueColor: AppColors.success,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('Total', style: AppTextStyles.titleMedium),
                          const Spacer(),
                          Text(Formatters.rupiah(total),
                              style: AppTextStyles.titleLarge
                                  .copyWith(color: AppColors.amberDark)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : NeuBottomBar(
              child: NeuButton(
                expand: true,
                accent: true,
                onPressed: state.isSubmitting ? null : _placeOrder,
                child: state.isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text('Buat Pesanan • ${Formatters.rupiah(total)}',
                        style:
                            AppTextStyles.button.copyWith(color: Colors.white)),
              ),
            ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.titleMedium);
}

/// Field input tamu (nama/HP) bergaya neumorphic (sumur cekung).
class _GuestField extends StatelessWidget {
  const _GuestField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return NeuInset(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: AppTextStyles.bodyLarge,
        decoration: InputDecoration(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }
}

/// Kartu pilihan tipe pesanan (dine-in / bawa pulang).
class _OrderTypeCard extends StatelessWidget {
  const _OrderTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final OrderType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Konvensi state terpilih (samakan dgn bottom nav & baris pembayaran):
    // permukaan CEKUNG + aksen amber pada ikon/teks — bukan isian penuh warna.
    final accent = selected ? AppColors.amberDark : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: NeuCard(
        depth: selected ? -4 : 5,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        radius: 16,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(type.icon,
                    color: selected ? AppColors.amber : AppColors.amberDark,
                    size: 26),
                if (selected)
                  const Positioned(
                    right: -10,
                    top: -6,
                    child: Icon(Icons.check_circle_rounded,
                        color: AppColors.amber, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(type.label,
                style: AppTextStyles.label.copyWith(
                  color: accent,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                )),
            const SizedBox(height: 2),
            Text(
              type.description,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherField extends StatelessWidget {
  const _VoucherField({
    required this.controller,
    required this.applied,
    required this.isLoading,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool applied;
  final bool isLoading;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !applied,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Mis. REHAT-10OFF-ABC123',
              prefixIcon: Icon(Icons.local_offer_outlined,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: applied
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          height: 52,
          child: applied
              ? OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: const Text('Hapus'))
              : ElevatedButton(
                  onPressed: isLoading ? null : onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                    minimumSize: const Size(0, 52),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.crema)),
                        )
                      : const Text('Pakai'),
                ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.method,
    required this.selected,
    required this.onTap,
  });
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeuCard(
        depth: selected ? -4 : 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        radius: 14,
        child: Row(
          children: [
            Icon(method.icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(width: 14),
            Text(method.label, style: AppTextStyles.bodyLarge),
            const Spacer(),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.amber : AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
