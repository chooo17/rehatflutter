import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../application/free_drink_controller.dart';
import '../data/free_drink_repository.dart';

/// Buka penukaran voucher gratis-minuman sebagai bottom sheet — dipakai dari
/// halaman Menu agar kasir tak perlu berpindah layar (flow lebih efisien).
Future<void> showFreeDrinkRedeemSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _FreeDrinkRedeemBody(inSheet: true),
  );
}

/// (Kasir) Tukar voucher gratis-minuman pelanggan: cari via HP (nama muncul
/// otomatis sembari mengetik), lalu tandai terpakai saat minuman diserahkan.
/// Tetap tersedia sebagai layar penuh (mis. deep-link), tapi akses utama kini
/// lewat ikon di halaman Menu.
class FreeDrinkRedeemScreen extends StatelessWidget {
  const FreeDrinkRedeemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tukar Voucher Gratis')),
      body: const _FreeDrinkRedeemBody(inSheet: false),
    );
  }
}

class _FreeDrinkRedeemBody extends ConsumerStatefulWidget {
  const _FreeDrinkRedeemBody({required this.inSheet});
  final bool inSheet;

  @override
  ConsumerState<_FreeDrinkRedeemBody> createState() =>
      _FreeDrinkRedeemBodyState();
}

class _FreeDrinkRedeemBodyState extends ConsumerState<_FreeDrinkRedeemBody> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  Timer? _debounce;

  static const _minDigits = 3;

  @override
  void initState() {
    super.initState();
    // Mulai bersih tiap dibuka (jangan tampilkan hasil pencarian sebelumnya).
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(freeDrinkControllerProvider.notifier).clearResults());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _digits => _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '').length;

  /// Pencarian LIVE: dipicu tiap ketikan (berdebounce). Nama pelanggan yang
  /// cocok muncul otomatis walau nomor HP belum lengkap.
  void _onChanged(String _) {
    _debounce?.cancel();
    if (_digits < _minDigits) {
      ref.read(freeDrinkControllerProvider.notifier).clearResults();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(freeDrinkControllerProvider.notifier).lookup(
            phone: _phoneCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
          );
    });
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
    final success = await ref
        .read(freeDrinkControllerProvider.notifier)
        .markUsed(v.voucherId);
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

  /// Tukar 9 stamp pelanggan langsung dari kasir + serahkan minuman (sekali tap).
  Future<void> _redeemStamp(StampRedeemCandidate c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Tukar stamp?'),
        content: Text(
            'Potong 9 stamp ${c.name} & serahkan 1 minuman gratis sekarang.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tukar & serahkan')),
        ],
      ),
    );
    if (ok != true) return;
    final success =
        await ref.read(freeDrinkControllerProvider.notifier).redeemStampFor(
              c,
              phone: _phoneCtrl.text.trim(),
              name: _nameCtrl.text.trim(),
            );
    if (!mounted) return;
    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('Stamp ${c.name} ditukar — 1 minuman gratis ✅')));
    } else {
      final err = ref.read(freeDrinkControllerProvider).errorMessage ??
          'Gagal menukar stamp.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(freeDrinkControllerProvider);
    final form = <Widget>[
        Text(
          'Ketik no. HP pelanggan — nama & voucher aktif muncul otomatis. '
          'Tandai terpakai saat minuman diserahkan.',
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
            autofocus: widget.inSheet,
            onChanged: _onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: 'No. HP pelanggan',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              suffixIcon: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.amber)),
                    )
                  : null,
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
            onChanged: _onChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
              hintText: 'Nama (opsional, untuk mempersempit)',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
          ),
        ),
    ];
    final content = ListView(
      shrinkWrap: widget.inSheet,
      physics: widget.inSheet ? const ClampingScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (widget.inSheet)
          Center(
            child: Text('Tukar Voucher Gratis',
                style: AppTextStyles.titleLarge),
          ),
        if (widget.inSheet) const SizedBox(height: 12),
        ...form,
        const SizedBox(height: 18),
        _results(state),
      ],
    );

    // Halaman penuh di layar lebar: form pencarian | hasil berdampingan.
    if (!widget.inSheet) {
      return AdaptiveColumns(
        narrowPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        widePadding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
        leftWidth: 400,
        narrowGap: 18,
        left: form,
        right: [_results(state)],
      );
    }
    // Dalam bottom sheet: hormati keyboard & batasi tinggi agar bisa di-scroll.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: content,
        ),
      ),
    );
  }

  Widget _results(FreeDrinkState state) {
    if (state.errorMessage != null) {
      return Text(state.errorMessage!,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error));
    }
    if (_digits < _minDigits) {
      return _hint(Icons.keyboard_rounded,
          'Ketik minimal $_minDigits angka no. HP untuk mulai mencari.');
    }
    final hasAny =
        state.vouchers.isNotEmpty || state.stampCandidates.isNotEmpty;
    if (!hasAny) {
      if (!state.searched || state.isLoading) {
        return _hint(Icons.search_rounded, 'Mencari…');
      }
      return _hint(Icons.local_cafe_outlined,
          'Tak ada voucher aktif atau stamp siap-tukar untuk no. HP itu.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.vouchers.isNotEmpty) ...[
          _sectionLabel('Voucher gratis aktif'),
          const SizedBox(height: 8),
          for (final v in state.vouchers) ...[
            _VoucherTile(
              voucher: v,
              busy: state.usingId == v.voucherId,
              onUse: () => _use(v),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (state.stampCandidates.isNotEmpty) ...[
          if (state.vouchers.isNotEmpty) const SizedBox(height: 8),
          _sectionLabel('Stamp siap tukar'),
          const SizedBox(height: 8),
          for (final c in state.stampCandidates) ...[
            _StampTile(
              candidate: c,
              busy: state.redeemingUserId == c.userId,
              onRedeem: () => _redeemStamp(c),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6),
      );

  Widget _hint(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(text,
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

/// Kartu pelanggan dengan stamp siap-tukar — kasir tukar + serahkan sekali tap.
class _StampTile extends StatelessWidget {
  const _StampTile(
      {required this.candidate, required this.busy, required this.onRedeem});
  final StampRedeemCandidate candidate;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final rewards = candidate.redeemableRewards;
    return NeuCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${candidate.availableStamps} stamp • '
                  '${rewards > 1 ? '$rewards kopi gratis siap' : '1 kopi gratis siap'}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeuButton(
            accent: true,
            onPressed: busy ? null : onRedeem,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white))
                : Text('Tukar & serahkan',
                    style: AppTextStyles.button.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
