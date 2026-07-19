import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../data/admin_report_repository.dart';

/// (Admin) Tutup kasir harian + rekonsiliasi pembayaran + ekspor CSV.
class ClosingReportScreen extends ConsumerWidget {
  const ClosingReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(closingDateProvider);
    final async = ref.watch(closingReportProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutup Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                ref.read(closingDateProvider.notifier).state = picked;
              }
            },
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat laporan.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.invalidate(closingReportProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (r) => RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => ref.invalidate(closingReportProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _DateHeader(date: date),
              const SizedBox(height: 16),
              _Section(title: 'Ringkasan Hari Ini', children: [
                _line('Omzet', r.summary.revenue, emphasize: true),
                _line('HPP (modal)', r.summary.cogs),
                _line('Laba kotor · ${r.summary.grossMarginPct}%',
                    r.summary.grossProfit, color: AppColors.success),
                _line('Pengeluaran', r.summary.expenses,
                    color: AppColors.error),
                const Divider(height: 22),
                _line('Laba bersih', r.summary.netProfit,
                    emphasize: true, color: AppColors.success),
                const SizedBox(height: 6),
                _plain('Pesanan', '${r.summary.orders}'),
                _plain('Item terjual', '${r.summary.itemsSold}'),
              ]),
              const SizedBox(height: 16),
              _Section(title: 'Rekonsiliasi Pembayaran', children: [
                _recon('QRIS masuk (settle)', r.qrisSettled,
                    color: AppColors.success),
                _recon('QRIS menggantung', r.qrisPending,
                    color: r.unsettled > 0
                        ? AppColors.warning
                        : AppColors.textSecondary),
                _recon('Tunai masuk', r.cashSettled),
                _recon('Dibatalkan', r.cancelled,
                    color: AppColors.textSecondary),
                const Divider(height: 22),
                _line('Kas tunai di laci (seharusnya)', r.expectedCashDrawer,
                    emphasize: true),
                const SizedBox(height: 4),
                _plain('Non-tunai diterima (cek vs DOKU)',
                    Formatters.rupiah(r.digitalReceived)),
              ]),
              if (r.unsettled > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${Formatters.rupiah(r.unsettled)} QRIS diinisiasi tapi '
                          'belum settle — cek dashboard DOKU untuk memastikan.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _exportCsv(context, r),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Ekspor CSV'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.espresso,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, ClosingReport r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = _buildCsv(r);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      // XFile.fromData → lintas platform (Android share sheet / unduhan web),
      // tanpa dart:io sehingga build web tetap aman.
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              mimeType: 'text/csv', name: 'tutup-kasir-${r.date}.csv')
        ],
        fileNameOverrides: ['tutup-kasir-${r.date}.csv'],
        subject: 'Tutup Kasir ${r.date}',
        text: 'Laporan tutup kasir Rehat — ${r.date}',
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal mengekspor CSV.')));
    }
  }

  String _buildCsv(ClosingReport r) {
    final s = r.summary;
    final lines = <String>[
      'Laporan Tutup Kasir,${r.date}',
      '',
      'Bagian,Keterangan,Nilai',
      '"Ringkasan","Omzet",${s.revenue}',
      '"Ringkasan","HPP (modal)",${s.cogs}',
      '"Ringkasan","Laba kotor",${s.grossProfit}',
      '"Ringkasan","Margin kotor (%)",${s.grossMarginPct}',
      '"Ringkasan","Pengeluaran",${s.expenses}',
      '"Ringkasan","Laba bersih",${s.netProfit}',
      '"Ringkasan","Jumlah pesanan",${s.orders}',
      '"Ringkasan","Item terjual",${s.itemsSold}',
      '',
      'Rekonsiliasi,Metode,Transaksi,Nominal',
      '"Rekonsiliasi","QRIS settle",${r.qrisSettled.count},${r.qrisSettled.amount}',
      '"Rekonsiliasi","QRIS menggantung",${r.qrisPending.count},${r.qrisPending.amount}',
      '"Rekonsiliasi","Tunai",${r.cashSettled.count},${r.cashSettled.amount}',
      '"Rekonsiliasi","Dibatalkan",${r.cancelled.count},${r.cancelled.amount}',
      '"Rekonsiliasi","Kas laci seharusnya",,${r.expectedCashDrawer}',
      '"Rekonsiliasi","Non-tunai diterima",,${r.digitalReceived}',
      '',
      'Item Terlaris,Nama,Qty,Omzet,Laba,Margin%',
      ...r.topItems.map((t) =>
          '"Item","${t.name}",${t.quantity},${t.revenue},${t.profit},${t.marginPct}'),
    ];
    return lines.join('\n');
  }

  Widget _line(String label, int value,
      {bool emphasize = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: emphasize
                    ? AppTextStyles.label
                    : AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
          ),
          Text(Formatters.rupiah(value),
              style: (emphasize ? AppTextStyles.titleMedium : AppTextStyles.label)
                  .copyWith(color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _plain(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Text(value, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _recon(String label, ReconLine v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('$label · ${v.count}×',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Text(Formatters.rupiah(v.amount),
              style: AppTextStyles.label
                  .copyWith(color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return Row(
      children: [
        Icon(Icons.point_of_sale_rounded, color: AppColors.espresso, size: 22),
        const SizedBox(width: 10),
        Text('${date.day} ${months[date.month - 1]} ${date.year}',
            style: AppTextStyles.titleLarge),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.amberDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
