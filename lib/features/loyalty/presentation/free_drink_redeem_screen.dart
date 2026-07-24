import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../application/free_drink_controller.dart';
import '../data/free_drink_repository.dart';

/// (Kasir) Tukar voucher gratis-minuman pelanggan: cari via HP + nama,
/// lalu tandai terpakai saat minuman diserahkan. Terpisah dari alur pesanan.
class FreeDrinkRedeemScreen extends ConsumerStatefulWidget {
  const FreeDrinkRedeemScreen({super.key});

  @override
  ConsumerState<FreeDrinkRedeemScreen> createState() =>
      _FreeDrinkRedeemScreenState();
}

class _FreeDrinkRedeemScreenState extends ConsumerState<FreeDrinkRedeemScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    await ref.read(freeDrinkControllerProvider.notifier).lookup(
          phone: _phoneCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
        );
  }

  Future<void> _use(FreeDrinkVoucher v) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Tandai terpakai?'),
        content: Text(
            'Serahkan 1 minuman gratis untuk ${v.customerName}, lalu tandai voucher ini terpakai.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tandai Terpakai')),
        ],
      ),
    );
    if (ok != true) return;
    final success =
        await ref.read(freeDrinkControllerProvider.notifier).markUsed(v.voucherId);
    if (!mounted) return;
    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('Voucher ${v.customerName} ditandai terpakai ✅')));
    } else {
      final err = ref.read(freeDrinkControllerProvider).errorMessage ??
          'Gagal menandai terpakai.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(freeDrinkControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tukar Voucher Gratis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Cari voucher gratis 1 minuman milik pelanggan via no. HP + nama, '
            'lalu tandai terpakai saat minuman diserahkan.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          NeuInset(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                hintText: 'No. HP pelanggan',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          NeuInset(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                hintText: 'Nama (opsional, untuk mempersempit)',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 14),
          NeuButton(
            expand: true,
            accent: true,
            onPressed: state.isLoading ? null : _search,
            child: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Text('Cari Voucher',
                    style: AppTextStyles.button.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          if (state.errorMessage != null)
            Text(state.errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error))
          else if (state.searched && state.vouchers.isEmpty && !state.isLoading)
            _empty()
          else
            for (final v in state.vouchers) ...[
              _VoucherTile(
                voucher: v,
                busy: state.usingId == v.voucherId,
                onUse: () => _use(v),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.local_cafe_outlined,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text('Tak ada voucher gratis aktif untuk pelanggan ini.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _VoucherTile extends StatelessWidget {
  const _VoucherTile(
      {required this.voucher, required this.busy, required this.onUse});
  final FreeDrinkVoucher voucher;
  final bool busy;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voucher.customerName, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Gratis 1 minuman • ${voucher.code}'
                  '${voucher.expiresAt != null ? ' • s/d ${Formatters.tanggal(voucher.expiresAt!)}' : ''}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeuButton(
            accent: true,
            onPressed: busy ? null : onUse,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white))
                : Text('Terpakai',
                    style: AppTextStyles.button.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
