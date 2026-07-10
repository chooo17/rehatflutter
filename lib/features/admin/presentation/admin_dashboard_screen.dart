import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../data/admin_report_repository.dart';

/// (Admin) Dashboard laporan penjualan: ringkasan, grafik harian, item terlaris.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  static const _ranges = [
    ('today', 'Hari ini'),
    ('7d', '7 Hari'),
    ('30d', '30 Hari'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(salesRangeProvider);
    final async = ref.watch(salesReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Penjualan')),
      body: RefreshIndicator(
        color: AppColors.amber,
        onRefresh: () async => ref.invalidate(salesReportProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            // Pemilih rentang waktu.
            NeuInset(
              padding: const EdgeInsets.all(6),
              radius: 16,
              child: Row(
                children: [
                  for (final (value, label) in _ranges)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: NeuButton(
                          onPressed: () =>
                              ref.read(salesRangeProvider.notifier).state = value,
                          accent: value == range,
                          radius: 11,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: value == range
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.amber)),
              ),
              error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(salesReportProvider)),
              data: (r) => _Report(report: r),
            ),
          ],
        ),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});
  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI 2x2.
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.payments_rounded,
                label: 'Pendapatan',
                value: Formatters.rupiah(report.revenue),
                accent: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icon: Icons.receipt_long_rounded,
                label: 'Pesanan',
                value: '${report.orders}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.local_cafe_rounded,
                label: 'Item terjual',
                value: '${report.itemsSold}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icon: Icons.trending_up_rounded,
                label: 'Rata-rata/pesanan',
                value: Formatters.rupiah(report.avgOrderValue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Pendapatan harian', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        NeuCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
          radius: 20,
          child: _RevenueChart(series: report.series),
        ),
        const SizedBox(height: 24),
        Text('Item terlaris', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        if (report.topItems.isEmpty)
          NeuCard(
            radius: 18,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada penjualan pada rentang ini.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ),
            ),
          )
        else
          for (var i = 0; i < report.topItems.length; i++) ...[
            _TopItemRow(rank: i + 1, item: report.topItems[i]),
            if (i != report.topItems.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: accent ? AppColors.amber : AppColors.espresso, size: 22),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: AppTextStyles.titleLarge.copyWith(
                    color: accent ? AppColors.amberDark : AppColors.textPrimary)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Grafik batang neumorphik sederhana (tanpa dependency chart).
class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.series});
  final List<SalesPoint> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('Tidak ada data.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ),
      );
    }
    final maxRevenue =
        series.map((e) => e.revenue).fold<int>(0, (m, v) => v > m ? v : m);
    // Untuk 30 hari, label tanggal ditampilkan jarang agar tidak berdesakan.
    final labelEvery = (series.length / 8).ceil().clamp(1, 999);
    const barMaxHeight = 130.0;

    return Column(
      children: [
        SizedBox(
          height: barMaxHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in series)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _Bar(
                      heightFactor:
                          maxRevenue == 0 ? 0 : p.revenue / maxRevenue,
                      maxHeight: barMaxHeight,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < series.length; i++)
              Expanded(
                child: Text(
                  i % labelEvery == 0 ? _dayLabel(series[i].date) : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary, fontSize: 9),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // '2026-07-10' -> '10/7'
  static String _dayLabel(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${int.tryParse(parts[2]) ?? parts[2]}/${int.tryParse(parts[1]) ?? parts[1]}';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.heightFactor, required this.maxHeight});
  final double heightFactor;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    // Batang minimal terlihat walau nilai 0 agar sumbu terbaca.
    final h = (heightFactor.clamp(0.0, 1.0) * maxHeight).clamp(3.0, maxHeight);
    return Align(
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: h),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Container(
          height: value,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [AppColors.amberDark, AppColors.amber],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  const _TopItemRow({required this.rank, required this.item});
  final int rank;
  final TopItem item;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      child: Row(
        children: [
          NeuInset(
            padding: EdgeInsets.zero,
            radius: 10,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Text('$rank',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.amberDark)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: AppTextStyles.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${item.quantity} terjual',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(Formatters.rupiah(item.revenue),
              style: AppTextStyles.label.copyWith(color: AppColors.amberDark)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 10),
            Text('Gagal memuat laporan.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
