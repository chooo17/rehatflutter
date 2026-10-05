import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../application/finance_overview_view.dart';
import '../data/finance_repository.dart';
import 'widgets/bucket_card.dart';

/// Layar Ringkasan Keuangan (Task 7) — pintu masuk modul Keuangan, khusus
/// pemilik. Laba Rugi & Biaya Tetap dicapai dari sini (lihat tombol AppBar).
///
/// Isi: 5 kartu amplop (boleh negatif — bukti nyata defisit, JANGAN
/// di-clamp), progres dana darurat, rambu break-even/runway (dengan
/// pengecualian "belum cukup data" / "margin ≤ 0" — lihat
/// [breakEvenDisplay]), tombol tarik per pos, dan aksi "Alokasikan tanggal
/// bolong" bila tutup kasir sempat tidak dibuka untuk hari WIB tertentu.
class FinanceOverviewScreen extends ConsumerWidget {
  const FinanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeOverviewProvider);
    final overview = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Keuangan'),
        actions: [
          IconButton(
            tooltip: 'Buku besar',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.pushNamed(RouteNames.financeLedger),
          ),
          IconButton(
            tooltip: 'Laba rugi',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.pushNamed(RouteNames.financePnl),
          ),
          IconButton(
            tooltip: 'Biaya tetap',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.pushNamed(RouteNames.financeFixedCosts),
          ),
          // Task 8 (Manajemen Stok Fase A) — satu-satunya tautan masuk ke
          // layar Perbandingan HPP, yang jadi HUB modul stok (dari sana
          // bercabang ke Kelola Bahan/Kelola Resep, Task 6-7).
          IconButton(
            tooltip: 'Perbandingan HPP',
            icon: const Icon(Icons.compare_arrows_outlined),
            onPressed: () => context.pushNamed(RouteNames.stockHppComparison),
          ),
        ],
      ),
      // Keep-previous-data: spinner HANYA saat belum ada data sama sekali.
      body: overview == null
          ? (async.hasError
              ? RefreshIndicator(
                  onRefresh: () async => ref.invalidate(financeOverviewProvider),
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
                        child: Text(
                          'Gagal memuat ringkasan keuangan. Tarik untuk mencoba lagi.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(financeOverviewProvider),
              // Layar lebar: peringatan & rambu | amplop berdampingan.
              child: AdaptiveColumns(
                narrowPadding: const EdgeInsets.all(16),
                widePadding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                narrowGap: 16,
                left: [
                  if (hasMissingAllocations(overview)) ...[
                    _MissingAllocationsCard(overview: overview),
                    const SizedBox(height: 16),
                  ],
                  if (hasOrphanedExpenses(overview)) ...[
                    _OrphanedExpensesCard(overview: overview),
                    const SizedBox(height: 16),
                  ],
                  _GuardsCard(overview: overview),
                  const SizedBox(height: 16),
                  _EmergencyProgressCard(overview: overview),
                ],
                right: [
                  Text('Amplop', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _BucketGrid(overview: overview),
                ],
              ),
            ),
    );
  }
}

class _MissingAllocationsCard extends ConsumerStatefulWidget {
  const _MissingAllocationsCard({required this.overview});
  final FinanceOverview overview;

  @override
  ConsumerState<_MissingAllocationsCard> createState() =>
      _MissingAllocationsCardState();
}

class _MissingAllocationsCardState extends ConsumerState<_MissingAllocationsCard> {
  bool _running = false;

  Future<void> _backfill() async {
    setState(() => _running = true);
    final repo = ref.read(financeRepositoryProvider);
    // Tanggal EKSPLISIT dari fungsi murni [datesToBackfill] — JANGAN pernah
    // kirim tanggal hari ini (mengunci alokasi pada omzet parsial, tak bisa
    // dikoreksi).
    final dates = datesToBackfill(widget.overview);
    final results = <AllocateResult>[];
    for (final date in dates) {
      try {
        results.add(await repo.allocate(date));
      } catch (_) {
        // Tanggal ini GAGAL TERKIRIM (jaringan/server) — beda dari
        // "dilewati" oleh backend. Tandai `failed:true` supaya
        // BackfillSummary tidak melaporkannya sebagai kondisi aman.
        results.add(failedAllocateResult());
      }
    }
    if (!mounted) return;
    final summary = BackfillSummary.fromResults(
      results,
      totalMissingCount: totalMissingCountFor(widget.overview),
    );
    setState(() => _running = false);
    ref.invalidate(financeOverviewProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(summary.message)));
  }

  @override
  Widget build(BuildContext context) {
    final summary = missingAllocationSummary(widget.overview);
    final sample = missingAllocationSample(widget.overview);
    return NeuCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pembukuan amplop bolong',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.warning),
                ),
                const SizedBox(height: 4),
                Text(
                  '$summary Tutup kasir tak pernah dibuka untuk hari itu — '
                  'omzet hari tersebut belum masuk amplop.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (sample.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Contoh tanggal: $sample',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                NeuButton(
                  onPressed: _running ? null : _backfill,
                  child: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Alokasikan tanggal bolong'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Peringatan pengeluaran yang tercatat TANPA memotong amplop (I-1/I-2,
/// review pengeluaran-potong-amplop) -- gejala kompensasi rollback yang
/// gagal saat `POST /admin/expenses`. Beda dari `_MissingAllocationsCard`:
/// TIDAK ADA tombol perbaikan otomatis, karena tidak ada endpoint koreksi
/// untuk `finance_ledger` (event-sourced, lihat CLAUDE.md §4) -- satu-
/// satunya jalan perbaikan adalah SQL manual di Supabase.
class _OrphanedExpensesCard extends StatelessWidget {
  const _OrphanedExpensesCard({required this.overview});
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengeluaran tanpa potongan amplop',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 4),
                Text(
                  orphanedExpensesSummary(overview),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tidak ada perbaikan otomatis untuk ini -- hubungi pemilik '
                  'untuk koreksi manual di database.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardsCard extends StatelessWidget {
  const _GuardsCard({required this.overview});
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final breakEven = breakEvenDisplay(overview);
    final runwayWarn = runwayWarning(overview);
    final basis = basisLabel(overview);
    final lastAllocated = lastAllocatedLabel(overview.lastAllocatedDate);

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rambu keputusan', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Omzet impas harian'),
              _BreakEvenValue(display: breakEven),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Runway operasional'),
              _RunwayValue(display: runwayDisplay(overview)),
            ],
          ),
          if (runwayWarn != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    runwayWarn,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ],
          if (basis.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              basis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (lastAllocated.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Pembukuan amplop terakhir: $lastAllocated',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakEvenValue extends StatelessWidget {
  const _BreakEvenValue({required this.display});
  final BreakEvenDisplay display;

  @override
  Widget build(BuildContext context) {
    switch (display.status) {
      case BreakEvenStatus.insufficientData:
        return Text(
          'Belum cukup data',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );
      case BreakEvenStatus.marginNonPositive:
        return Text(
          'Margin ≤ 0 — cek harga jual',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
        );
      case BreakEvenStatus.costsUnknown:
        return Text(
          'Isi Biaya Tetap dulu',
          textAlign: TextAlign.end,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold),
        );
      case BreakEvenStatus.ok:
        return Text(
          Formatters.rupiah(display.amount),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold, color: AppColors.espresso),
        );
    }
  }
}

class _RunwayValue extends StatelessWidget {
  const _RunwayValue({required this.display});
  final RunwayDisplay display;

  @override
  Widget build(BuildContext context) {
    switch (display.status) {
      case RunwayStatus.unknown:
        return Text(
          'Belum bisa dihitung',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );
      case RunwayStatus.deficit:
        return Text(
          'Defisit ${display.days.abs()} hari',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
        );
      case RunwayStatus.ok:
        return Text(
          runwayOkLabel(display.days),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold, color: AppColors.espresso),
        );
    }
  }
}

class _EmergencyProgressCard extends StatelessWidget {
  const _EmergencyProgressCard({required this.overview});
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final guards = overview.guards;
    final fraction = emergencyBarFraction(guards.emergencyPct);
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dana darurat', style: Theme.of(context).textTheme.titleSmall),
              if (guards.emergencyReached)
                const _Badge(text: 'Tercapai', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: AppColors.divider,
              color: guards.emergencyReached ? AppColors.success : AppColors.amber,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // Minor (final whole-branch review): `emergencyTarget == 0`
            // berarti pemilik BELUM PERNAH mengatur target (bukan "target
            // Rp0 tercapai") — tampilkan itu apa adanya, bukan "0% dari
            // target Rp0" yang membingungkan (seolah target memang nol).
            overview.settings.emergencyTarget <= 0
                ? 'Target belum diatur'
                : '${guards.emergencyPct}% dari target '
                    '${Formatters.rupiah(overview.settings.emergencyTarget)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BucketGrid extends ConsumerWidget {
  const _BucketGrid({required this.overview});
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = overview.balances;
    final g = overview.guards;
    final buckets = <_BucketSpec>[
      _BucketSpec('restock', 'Restock', Icons.inventory_2_outlined, b.restock),
      _BucketSpec('operational', 'Operasional', Icons.build_outlined, b.operational),
      _BucketSpec('personal', 'Pribadi', Icons.person_outline, b.personal),
      _BucketSpec('scaling', 'Scaling', Icons.trending_up_rounded, b.scaling),
      _BucketSpec('emergency', 'Dana Darurat', Icons.shield_outlined, b.emergency),
    ];

    // `Wrap` alih-alih `GridView` + `childAspectRatio` tetap (final
    // whole-branch review, C-1): tinggi sel GridView tetap TIDAK bisa
    // menampung isi kartu untuk semua kombinasi nyata (saldo jutaan yang
    // membungkus 2-3 baris, tombol Tarik, teks defisit, DAN
    // `blockedReason` sekaligus) — diverifikasi overflow 52-334px pada
    // 360×800 logis (HP standar) untuk keempat kombinasi
    // (normal/diblokir × positif/defisit). `Wrap` membiarkan setiap kartu
    // mengambil TINGGI INTRINSIK isinya sendiri (lewat `SizedBox` yang
    // hanya mematok LEBAR, bukan tinggi) — kartu boleh setinggi apa pun
    // yang dibutuhkan kontennya, tak ada batas yang bisa terlampaui.
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final spec in buckets)
              SizedBox(
                width: cardWidth,
                child: BucketCard(
                  label: spec.label,
                  icon: spec.icon,
                  balance: spec.balance,
                  withdrawState: withdrawButtonState(bucket: spec.key, guards: g),
                  onWithdraw: () => _showWithdrawSheet(context, spec),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showWithdrawSheet(BuildContext context, _BucketSpec spec) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WithdrawSheet(bucket: spec.key, label: spec.label),
    );
  }
}

class _BucketSpec {
  const _BucketSpec(this.key, this.label, this.icon, this.balance);
  final String key;
  final String label;
  final IconData icon;
  final int balance;
}

/// StatefulWidget terpisah supaya controller punya lifecycle jelas dan
/// dibuang lewat dispose() — termasuk saat sheet ditutup dengan swipe
/// (bukan hanya lewat tombol Tarik). Pola sama seperti `_AddFixedCostSheet`
/// di Tahap 1 (temuan review sebelumnya: kebocoran TextEditingController).
class _WithdrawSheet extends ConsumerStatefulWidget {
  const _WithdrawSheet({required this.bucket, required this.label});
  final String bucket;
  final String label;

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.parse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    setState(() => _submitting = true);
    try {
      await ref.read(financeRepositoryProvider).withdraw(
            bucket: widget.bucket,
            amount: amount,
            note: _noteCtrl.text.trim(),
          );
      ref.invalidate(financeOverviewProvider);
      if (!mounted) return;
      // Minor (final whole-branch review): dulu sheet ditutup TANPA umpan
      // balik apa pun setelah penarikan berhasil — aksi yang menulis uang
      // wajib memberi konfirmasi eksplisit (nominal & pos), bukan diam-diam
      // hilang. `ScaffoldMessenger` diambil SEBELUM `pop()` (context sheet
      // masih hidup di sini), lalu snackbar ditampilkan SESUDAH pop —
      // `ScaffoldMessengerState` tetap valid karena melekat ke Scaffold
      // layar Ringkasan di baliknya, bukan ke sheet yang baru ditutup.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(
          '${Formatters.rupiah(amount)} berhasil ditarik dari ${widget.label}.',
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(withdrawErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarik dari ${widget.label}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
              validator: (v) {
                final n = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
                if (n == null || n <= 0) return 'Nominal harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              // I-1 (final whole-branch review): backend (`withdrawSchema`,
              // `note: z.string().max(200)`) menolak catatan >200 karakter
              // dengan pesan Zod BERBAHASA INGGRIS ("Too big: expected
              // string to have <=200 characters") yang lolos apa adanya
              // lewat `withdrawErrorMessage`. `maxLength` di sini mencegah
              // pengguna mengetik melebihi batas SAMA SEKALI — jalur 400 ini
              // seharusnya tak pernah tercapai lagi dari UI.
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Catatan'),
              validator: (v) {
                final trimmed = (v ?? '').trim();
                if (trimmed.isEmpty) return 'Catatan wajib diisi';
                if (trimmed.length > 200) {
                  return 'Catatan maksimal 200 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tarik'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
