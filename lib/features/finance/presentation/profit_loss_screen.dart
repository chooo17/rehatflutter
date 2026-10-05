import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_names.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../data/finance_repository.dart';

/// Info "bulan berjalan" untuk penanda di layar Laba Rugi: berapa hari sudah
/// lewat dari total hari bulan yang ditampilkan.
class MonthProgress {
  const MonthProgress({required this.daysElapsed, required this.daysInMonth});

  final int daysElapsed;
  final int daysInMonth;
}

/// Fungsi murni: apakah [displayedMonth] adalah bulan yang sedang berjalan
/// dibandingkan [todayWib] (keduanya harus sudah dalam WIB)? Bila ya,
/// kembalikan berapa hari sudah lewat dari total hari bulan itu. Bila bukan
/// bulan berjalan (lampau atau depan), kembalikan null — layar tidak boleh
/// menampilkan penanda apa pun untuk bulan yang sudah selesai.
///
/// Sengaja tidak menyentuh aritmetika laba rugi sama sekali — hanya
/// memberikan konteks agar biaya tetap yang dibebankan penuh di awal bulan
/// tidak disalahartikan sebagai kerugian nyata.
MonthProgress? monthProgress(DateTime displayedMonth, DateTime todayWib) {
  if (displayedMonth.year != todayWib.year || displayedMonth.month != todayWib.month) {
    return null;
  }
  final daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
  return MonthProgress(daysElapsed: todayWib.day, daysInMonth: daysInMonth);
}

/// Laporan laba rugi bulanan.
///
/// Berbeda dari "laba bersih" di dashboard lama: pengeluaran restock TIDAK
/// dipotong dua kali (sudah terhitung di HPP), dan biaya tetap ikut masuk.
class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(pnlMonthProvider);
    final async = ref.watch(pnlProvider);
    final p = async.valueOrNull;

    final progress = monthProgress(month, Formatters.toWib(DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laba Rugi'),
        actions: [
          IconButton(
            tooltip: 'Biaya tetap',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.pushNamed(RouteNames.financeFixedCosts),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthPicker(month: month, ref: ref),
          Expanded(
            child: p == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(pnlProvider),
                    // Layar lebar: laporan laba rugi | rincian biaya tetap.
                    child: AdaptiveColumns(
                      narrowPadding: const EdgeInsets.all(16),
                      widePadding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                      leftFlex: 3,
                      rightFlex: 2,
                      narrowGap: 24,
                      left: [
                        if (progress != null) ...[
                          _MonthInProgressBanner(progress: progress),
                          const SizedBox(height: 16),
                        ],
                        _Row(label: 'Omzet', value: p.revenue, bold: true),
                        _Row(label: 'HPP (modal bahan)', value: -p.cogs),
                        const Divider(),
                        _Row(
                          label: 'Laba Kotor',
                          value: p.grossProfit,
                          bold: true,
                          suffix: '${p.grossMarginPct}%',
                        ),
                        _Row(label: 'Biaya tetap', value: -p.fixedCosts),
                        _Row(
                          label: 'Biaya variabel (non-restock)',
                          value: -p.variableExpenses,
                          warning: p.variableExpensesUnavailable,
                          warningText: p.variableExpensesUnavailable
                              ? 'Gagal dimuat — angka Rp0 di atas BUKAN data '
                                  'nyata, jadi laba bersih di bawah belum final.'
                              : null,
                        ),
                        _Row(label: 'Biaya transaksi QRIS', value: -p.paymentFees),
                        const Divider(),
                        _Row(
                          label: 'Laba Bersih',
                          value: p.netProfit,
                          bold: true,
                          suffix: '${p.netMarginPct}%',
                          highlight: true,
                        ),
                      ],
                      right: [
                        // NeuCard sudah ber-padding 16 secara bawaan.
                        NeuCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rincian biaya tetap',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              if (p.fixedCostItems.isEmpty)
                                const Text(
                                    'Belum ada biaya tetap. Laba bersih di atas '
                                    'masih terlalu optimis.'),
                              for (final c in p.fixedCostItems)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(c.name),
                                      Text(Formatters.rupiah(c.amount)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Penanda bahwa bulan yang ditampilkan masih berjalan — biaya tetap sudah
/// dibebankan penuh sebulan sehingga laba bersih terlihat lebih rendah dari
/// yang sebenarnya akan terjadi di akhir bulan.
class _MonthInProgressBanner extends StatelessWidget {
  const _MonthInProgressBanner({required this.progress});

  final MonthProgress progress;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bulan berjalan — ${progress.daysElapsed} dari '
              '${progress.daysInMonth} hari. Biaya tetap sudah dibebankan '
              'penuh, jadi laba bersih akan terlihat lebih rendah sampai '
              'akhir bulan.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.ref});
  final DateTime month;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    void shift(int delta) {
      ref.read(pnlMonthProvider.notifier).state =
          DateTime(month.year, month.month + delta);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => shift(-1)),
          Text(
            // Format langsung dari year/month `month` — JANGAN lewat
            // Formatters.tanggal (yang menerapkan toWib lagi). `month` sudah
            // berupa DateTime(y, m) hasil field WIB; konversi toWib kedua
            // kalinya menggeser tanggal mundur di zona timur WIB (WITA/WIT),
            // membuat header salah bulan padahal datanya benar.
            DateFormat('MMM yyyy', 'id_ID').format(DateTime(month.year, month.month)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => shift(1)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.suffix,
    this.highlight = false,
    this.warning = false,
    this.warningText,
  });

  final String label;
  final int value;
  final bool bold;
  final String? suffix;
  final bool highlight;

  /// True bila baris ini butuh diwarnai peringatan (mis. data yang gagal
  /// dimuat dan jatuh ke 0, bukan nilai nyata).
  final bool warning;

  /// Teks penjelasan tambahan yang tampil di bawah baris saat [warning].
  final String? warningText;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: warning
              ? AppColors.warning
              : highlight
                  ? (value >= 0 ? AppColors.success : AppColors.error)
                  : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(label, style: style)),
                    if (warning) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.warning),
                    ],
                  ],
                ),
              ),
              if (suffix != null) ...[
                Text(suffix!, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 8),
              ],
              Text(Formatters.rupiah(value), style: style),
            ],
          ),
          if (warning && warningText != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                warningText!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
