import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../data/admin_report_repository.dart';

/// (Admin) Analitik lanjutan: jam sibuk, hari tersibuk, AOV, repeat-rate.
class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analyticsRangeProvider);
    final async = ref.watch(analyticsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Analitik')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat analitik.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.invalidate(analyticsProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (a) => RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => ref.invalidate(analyticsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _RangePills(active: range, onPick: (r) =>
                  ref.read(analyticsRangeProvider.notifier).state = r),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _Kpi(
                    label: 'Pelanggan berulang',
                    value: '${a.repeatRatePct}%',
                    sub: 'dari ${a.uniqueBuyers} pembeli')),
                const SizedBox(width: 12),
                Expanded(child: _Kpi(
                    label: 'Rata-rata pesanan',
                    value: Formatters.rupiah(a.avgOrderValue),
                    sub: '${a.orders} pesanan')),
              ]),
              const SizedBox(height: 12),
              _Kpi(
                label: 'Jam paling sibuk',
                value: a.peakHour == null ? '—' : '${a.peakHour.toString().padLeft(2, '0')}.00',
                sub: 'gunakan untuk jadwal staf & happy hour',
                wide: true,
              ),
              const SizedBox(height: 24),
              Text('Pesanan per jam', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              _BarChart(
                values: a.hourly,
                labelEvery: 3,
                labelBuilder: (i) => i.toString().padLeft(2, '0'),
                highlight: a.peakHour,
              ),
              const SizedBox(height: 24),
              Text('Pesanan per hari', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              _BarChart(
                values: a.dow,
                labelEvery: 1,
                labelBuilder: (i) =>
                    const ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'][i],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangePills extends StatelessWidget {
  const _RangePills({required this.active, required this.onPick});
  final String active;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    const opts = [('today', 'Hari ini'), ('7d', '7 hari'), ('30d', '30 hari')];
    return Row(
      children: [
        for (final o in opts)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.$2),
              selected: active == o.$1,
              onSelected: (_) => onPick(o.$1),
            ),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.sub, this.wide = false});
  final String label;
  final String value;
  final String? sub;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.displaySmall
                  .copyWith(color: AppColors.espresso)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Grafik batang sederhana (tanpa dependency chart).
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labelEvery,
    required this.labelBuilder,
    this.highlight,
  });
  final List<int> values;
  final int labelEvery;
  final String Function(int index) labelBuilder;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Text('Tidak ada data.',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary));
    }
    final maxV = values.fold<int>(0, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: maxV == 0 ? 2 : (values[i] / maxV) * 104 + 2,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: i == highlight
                            ? AppColors.amberDark
                            : AppColors.amber,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: i % labelEvery == 0
                          ? FittedBox(
                              child: Text(labelBuilder(i),
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 9)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
