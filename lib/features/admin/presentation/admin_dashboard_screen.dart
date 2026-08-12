import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../../finance/data/finance_repository.dart';
import '../application/expense_bucket.dart';
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
    final date = ref.watch(salesDateProvider);
    final async = ref.watch(salesReportProvider);

    Future<void> pickDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: date ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
      );
      if (picked != null) ref.read(salesDateProvider.notifier).state = picked;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Penjualan')),
      body: RefreshIndicator(
        color: AppColors.amber,
        onRefresh: () async {
          ref.invalidate(salesReportProvider);
          ref.invalidate(expensesProvider);
          ref.invalidate(salesCalendarProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            // Pemilih rentang waktu (pill) — nonaktif bila tanggal spesifik dipilih.
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
                          onPressed: () {
                            ref.read(salesRangeProvider.notifier).state = value;
                            ref.read(salesDateProvider.notifier).state = null;
                          },
                          accent: value == range && date == null,
                          radius: 11,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: value == range && date == null
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
            const SizedBox(height: 10),
            // Pilih tanggal spesifik.
            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    onPressed: pickDate,
                    accent: date != null,
                    radius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16,
                            color: date != null
                                ? Colors.white
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          date != null
                              ? Formatters.tanggal(date)
                              : 'Pilih tanggal',
                          style: AppTextStyles.caption.copyWith(
                            color: date != null
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () =>
                        ref.read(salesDateProvider.notifier).state = null,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Hapus filter tanggal',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            // Kartu Keuangan — hanya tampil untuk pemilik. Ini kosmetik;
            // batas nyata ada di middleware requireFinanceAccess di backend.
            // Saat memuat/error, kartu disembunyikan (bukan urusan kasir).
            ref.watch(financeAccessProvider).maybeWhen(
                  data: (allowed) => allowed
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: NeuCard(
                            padding: EdgeInsets.zero,
                            radius: 18,
                            child: ListTile(
                              leading: Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.espresso),
                              title: const Text('Keuangan'),
                              subtitle: const Text('Amplop, laba rugi & biaya tetap'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  context.pushNamed(RouteNames.financeOverview),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
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
            const SizedBox(height: 24),
            const _SalesCalendar(),
            const SizedBox(height: 24),
            const _ExpensesSection(),
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
        // KPI utama: omzet & "Laba kotor - pengeluaran" (angka legacy dari
        // endpoint /admin/reports/sales — masih menghitung ganda restock &
        // belum memotong biaya tetap. Label SENGAJA bukan "Laba bersih" agar
        // tidak bentrok dengan angka laba rugi modul Keuangan yang lebih
        // akurat; lihat CLAUDE.md §4).
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.payments_rounded,
                label: 'Total omzet',
                value: Formatters.rupiah(report.revenue),
                accent: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icon: Icons.savings_rounded,
                label: 'Laba kotor − pengeluaran',
                value: Formatters.rupiah(report.netProfit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // HPP (modal) & laba kotor + margin riil berbasis cost_price.
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.inventory_2_rounded,
                label: 'HPP (modal)',
                value: Formatters.rupiah(report.cogs),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icon: Icons.trending_up_rounded,
                label: 'Laba kotor · ${report.grossMarginPct}%',
                value: Formatters.rupiah(report.grossProfit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Penerimaan dipisah metode bayar.
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.qr_code_2_rounded,
                label: 'Diterima via QRIS',
                value: Formatters.rupiah(report.qrisRevenue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icon: Icons.payments_outlined,
                label: 'Diterima Tunai',
                value: Formatters.rupiah(report.cashRevenue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Kas tunai di kasir = omzet - QRIS - pengeluaran.
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Kas Tunai Kasir',
                value: Formatters.rupiah(report.cashInDrawer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icon: Icons.money_off_rounded,
                label: 'Pengeluaran',
                value: Formatters.rupiah(report.expenses),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.receipt_long_rounded,
                label: 'Pesanan',
                value: '${report.orders}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icon: Icons.local_cafe_rounded,
                label: 'Item terjual',
                value: '${report.itemsSold}',
              ),
            ),
          ],
        ),
        if (report.stampRedemptions != null) ...[
          const SizedBox(height: 12),
          _KpiCard(
            icon: Icons.card_giftcard_rounded,
            label: 'Kopi gratis ditukar (stamp)'
                '${report.stampRedemptionsUsed != null ? ' • ${report.stampRedemptionsUsed} terpakai' : ''}',
            value: '${report.stampRedemptions}',
          ),
        ],
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
                Text(
                    '${item.quantity} terjual'
                    '${item.cost > 0 ? ' · margin ${item.marginPct}%' : ''}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.rupiah(item.revenue),
                  style:
                      AppTextStyles.label.copyWith(color: AppColors.amberDark)),
              if (item.cost > 0)
                Text('+${Formatters.rupiah(item.profit)}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.success)),
            ],
          ),
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

const _idMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Kalender penjualan: omzet harian (dalam ribuan, mis. 1.435.000 → 1435).
class _SalesCalendar extends ConsumerWidget {
  const _SalesCalendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(calendarMonthProvider);
    final data = ref.watch(salesCalendarProvider).valueOrNull ?? const {};
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Senin sebagai kolom pertama.

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final key = '${month.year.toString().padLeft(4, '0')}-'
          '${month.month.toString().padLeft(2, '0')}-'
          '${d.toString().padLeft(2, '0')}';
      final rev = data[key] ?? 0;
      cells.add(_DayCell(day: d, omzetK: rev > 0 ? (rev / 1000).round() : null));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kalender Penjualan', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        NeuCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          radius: 20,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => ref.read(calendarMonthProvider.notifier).state =
                        DateTime(month.year, month.month - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text('${_idMonths[month.month - 1]} ${month.year}',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label),
                  ),
                  IconButton(
                    onPressed: () => ref.read(calendarMonthProvider.notifier).state =
                        DateTime(month.year, month.month + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              Row(
                children: [
                  for (final w in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
                    Expanded(
                      child: Text(w,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary, fontSize: 10)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.82,
                children: cells,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, this.omzetK});
  final int day;
  final int? omzetK;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: omzetK != null
            ? AppColors.amber.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$day',
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 1),
          if (omzetK != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$omzetK',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.amberDark,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            )
          else
            const Text(' ', style: TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}

/// Bagian pengeluaran: total + catat baru + daftar (dengan hapus).
class _ExpensesSection extends ConsumerWidget {
  const _ExpensesSection();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_AddExpenseResult>(
      context: context,
      builder: (ctx) => const _AddExpenseDialog(),
    );
    if (result == null) return;
    // `context` NON-AKTIF setelah `await` di atas (dialog bisa memakan waktu
    // & widget ini bisa sudah dilepas) — tak dipakai lagi di bawah sini,
    // hanya `ref` (aman dipakai setelah await selama widget masih hidup;
    // Riverpod membuang panggilan pada provider yang sudah dibuang).
    await ref.read(adminReportRepositoryProvider).addExpense(
          amount: result.amount,
          note: result.note,
          bucket: result.bucket,
        );
    ref.invalidate(expensesProvider);
    ref.invalidate(salesReportProvider);
  }

  Future<void> _delete(WidgetRef ref, String id) async {
    await ref.read(adminReportRepositoryProvider).deleteExpense(id);
    ref.invalidate(expensesProvider);
    ref.invalidate(salesReportProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expensesProvider);
    final list = async.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pengeluaran', style: AppTextStyles.titleMedium),
            const Spacer(),
            NeuButton(
              onPressed: () => _add(context, ref),
              accent: true,
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('Catat',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (async.hasError)
          NeuCard(
            radius: 14,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Text(
                  'Fitur pengeluaran belum aktif. Jalankan migrasi 007_add_expenses.sql di Supabase.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
          )
        else if (list == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.amber)),
          )
        else ...[
          NeuCard(
            padding: const EdgeInsets.all(14),
            radius: 16,
            child: Row(
              children: [
                Icon(Icons.money_off_rounded, color: AppColors.amberDark),
                const SizedBox(width: 10),
                Text('Total pengeluaran', style: AppTextStyles.bodyMedium),
                const Spacer(),
                Text(Formatters.rupiah(list.total),
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.amberDark)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (list.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Belum ada pengeluaran pada rentang ini.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            )
          else
            for (final e in list.items) ...[
              _ExpenseRow(item: e, onDelete: () => _delete(ref, e.id)),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }
}

/// Hasil dialog "Catat Pengeluaran" — `null` dari `showDialog` berarti
/// dibatalkan (tombol Batal / tutup di luar dialog), instance ini berarti
/// "Simpan" ditekan dengan input valid.
class _AddExpenseResult {
  const _AddExpenseResult({required this.amount, required this.note, required this.bucket});
  final int amount;
  final String note;
  final String bucket;
}

/// Dialog "Catat Pengeluaran" — `StatefulWidget` tersendiri (bukan dibangun
/// inline di `_add`) supaya `TextEditingController` yang dipakainya bisa
/// di-`dispose` dengan benar. Sebelumnya dua controller (`amountCtrl`,
/// `noteCtrl`) dibuat langsung di method `_add` lalu dibiarkan begitu saja
/// setelah dialog ditutup — bocor setiap kali dialog dibuka. Pola yang sama
/// (ekstraksi jadi `StatefulWidget` sendiri) sudah dipakai di layar keuangan
/// untuk memperbaiki kebocoran serupa (lihat CLAUDE.md §4, NeuButton).
class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  late final TextEditingController _amountCtrl = TextEditingController();
  late final TextEditingController _noteCtrl = TextEditingController();
  // Default 'restock' — mempertahankan perilaku lama (satu-satunya pos yang
  // pernah dipakai sebelum pemilih ini ada) untuk kasir yang menekan Simpan
  // tanpa mengubah pilihan.
  String _bucket = defaultExpenseBucket;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) return;
    Navigator.pop(
      context,
      _AddExpenseResult(
        amount: amount,
        note: _noteCtrl.text,
        bucket: resolveExpenseBucket(_bucket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Catat Pengeluaran', style: AppTextStyles.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)', prefixText: 'Rp '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
          ),
          const SizedBox(height: 14),
          Text('Pos (amplop)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _bucket,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [
              for (final b in expenseBucketOptions)
                DropdownMenuItem(value: b, child: Text(expenseBucketLabel(b))),
            ],
            onChanged: (v) => setState(() => _bucket = v ?? defaultExpenseBucket),
          ),
          const SizedBox(height: 8),
          Text(
            'Pengeluaran ini akan memotong saldo pos yang dipilih.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        TextButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.item, required this.onDelete});
  final ExpenseItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: 14,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.note.isEmpty ? 'Pengeluaran' : item.note,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text(Formatters.tanggalJam(item.spentAt),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    Text('  ·  ',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    Text(expenseBucketLabel(item.bucket),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.amberDark, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Text(Formatters.rupiah(item.amount),
              style: AppTextStyles.label.copyWith(color: AppColors.amberDark)),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
