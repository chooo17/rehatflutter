import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/star_rating.dart';
import '../data/review_repository.dart';

/// Bottom sheet untuk menulis ulasan satu item pesanan.
///
/// Mengembalikan `true` lewat Navigator bila ulasan berhasil dikirim.
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({
    super.key,
    required this.menuItemId,
    required this.orderId,
    required this.itemName,
  });

  final String menuItemId;
  final String orderId;
  final String itemName;

  static Future<bool?> show(
    BuildContext context, {
    required String menuItemId,
    required String orderId,
    required String itemName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ReviewSheet(
        menuItemId: menuItemId,
        orderId: orderId,
        itemName: itemName,
      ),
    );
  }

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reviewRepositoryProvider).submitReview(
            menuItemId: widget.menuItemId,
            orderId: widget.orderId,
            rating: _rating,
            comment: _commentCtrl.text.trim(),
          );
      // Segarkan daftar ulasan menu terkait.
      ref.invalidate(itemReviewsProvider(widget.menuItemId));
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Terima kasih atas ulasanmu!')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal mengirim ulasan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Beri ulasan', style: AppTextStyles.displaySmall),
          const SizedBox(height: 4),
          Text(widget.itemName,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Center(
            child: StarRating(
              rating: _rating.toDouble(),
              size: 40,
              onChanged: (v) => setState(() => _rating = v),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Ceritakan pengalamanmu (opsional)…',
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Kirim Ulasan',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
