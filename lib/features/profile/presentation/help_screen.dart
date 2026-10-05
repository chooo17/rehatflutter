import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/neu.dart';

/// Halaman bantuan & FAQ sederhana.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'Bagaimana cara memesan?',
      'Pilih menu, atur ukuran/gula/suhu, tambahkan ke keranjang, lalu lanjut ke pembayaran.'
    ),
    (
      'Bagaimana cara mendapat poin?',
      'Setiap pesanan yang selesai memberi poin loyalitas yang bisa dilihat di tab Loyalti. '
          'Poin menentukan tier keanggotaanmu (Bronze–Platinum); untuk saat ini belum bisa ditukar langsung.'
    ),
    (
      'Apa itu stamp card?',
      'Kumpulkan stamp dari setiap pembelian. Saat stamp penuh, tunjukkan ke kasir untuk menukar kopi gratis.'
    ),
    (
      'Bagaimana cara pakai voucher?',
      'Voucher dari Spin/promo muncul di tab Loyalti. Salin kodenya dan masukkan saat checkout.'
    ),
    (
      'Berapa kali bisa main Spin?',
      'Satu kali setiap hari. Hadiah voucher otomatis masuk ke akunmu.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Pertanyaan Umum', style: AppTextStyles.displaySmall),
          const SizedBox(height: 12),
          // Layar lebar: FAQ dibagi dua kolom INDEPENDEN (bukan grid per
          // baris) supaya membuka satu jawaban tak ikut memanjangkan kartu
          // di sebelahnya.
          LayoutBuilder(builder: (context, c) {
            Widget faqTile((String, String) faq) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NeuCard(
                    padding: EdgeInsets.zero,
                    radius: 16,
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        iconColor: AppColors.amberDark,
                        collapsedIconColor: AppColors.textSecondary,
                        title: Text(faq.$1, style: AppTextStyles.titleMedium),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          Text(faq.$2,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                );
            if (c.maxWidth < 900) {
              return Column(children: [for (final f in _faqs) faqTile(f)]);
            }
            final half = (_faqs.length / 2).ceil();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                      children: [for (final f in _faqs.take(half)) faqTile(f)]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      children: [for (final f in _faqs.skip(half)) faqTile(f)]),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          NeuCard(
            padding: const EdgeInsets.all(16),
            radius: 16,
            child: Row(
              children: [
                Icon(Icons.support_agent_rounded, color: AppColors.amberDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Butuh bantuan lain? Hubungi kami di halo@rehat.coffee',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
