import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../../admin/data/admin_report_repository.dart';
import '../application/stock_view.dart';
import '../data/stock_repository.dart';

/// Layar Perbandingan HPP (Manajemen Stok Fase A, **Task 8 — deliverable
/// utama Fase A**) — KHUSUS PEMILIK, sama guard dengan Master Bahan
/// (Task 6) & Entri Resep (Task 7): endpoint di belakang `authenticate` +
/// `requireFinanceAccess`.
///
/// Menjawab "apakah tebakan HPP manual (`cost_price`) saya selama ini benar"
/// — per menu: `cost_price` lama, HPP terhitung dari resep (panas/dingin),
/// selisih rupiah & persen, diurutkan **selisih terbesar di atas**
/// ([sortHppRowsByBiggestDifference]). Ringkasan di puncak: berapa menu
/// sudah punya resep, dan dampak gabungan DITIMBANG porsi terjual (BUKAN
/// rata-rata polos, lihat [computeWeightedHppImpact]).
///
/// Ini SATU-SATUNYA layar yang menautkan Task 6 (`stock-ingredients`) &
/// Task 7 (`stock-recipe-list`) — keduanya sengaja dibiarkan tanpa tautan
/// navigasi sampai task ini, karena layar ini adalah HUB modul stok:
/// dijangkau dari tombol AppBar di `FinanceOverviewScreen`, dan dari sini
/// pemilik bercabang ke Kelola Bahan / Kelola Resep lewat tombol AppBar-nya
/// sendiri.
class HppComparisonScreen extends ConsumerWidget {
  const HppComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hppAsync = ref.watch(hppComparisonProvider);
    final topAsync = ref.watch(hppImpactTopSellingItemsProvider);

    final hppRows = hppAsync.valueOrNull;
    final topItems = topAsync.valueOrNull;

    // Keep-previous-data: spinner HANYA saat SALAH SATU dari kedua sumber
    // belum pernah punya data sama sekali — sama pola dengan
    // RecipeListScreen/FinanceOverviewScreen.
    final loading = hppRows == null || topItems == null;
    final hasError = hppAsync.hasError || topAsync.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perbandingan HPP'),
        actions: [
          IconButton(
            tooltip: 'Kelola bahan',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.pushNamed(RouteNames.stockIngredients),
          ),
          IconButton(
            tooltip: 'Kelola resep',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.pushNamed(RouteNames.stockRecipeList),
          ),
        ],
      ),
      body: loading
          ? (hasError
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Gagal memuat perbandingan HPP.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
          : Builder(builder: (context) {
              final sorted = sortHppRowsByBiggestDifference(hppRows);
              final eligible =
                  eligibleHppImpactInputs(hppRows: hppRows, topItems: topItems);
              final impact = computeWeightedHppImpact(eligible);
              final withRecipe = hppRows.where((r) => r.complete).length;

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(hppComparisonProvider);
                  ref.invalidate(hppImpactTopSellingItemsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(
                      withRecipe: withRecipe,
                      total: hppRows.length,
                      impact: impact,
                    ),
                    const SizedBox(height: 16),
                    if (sorted.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('Belum ada menu.', textAlign: TextAlign.center),
                      )
                    else
                      for (final row in sorted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HppRowTile(row: row),
                        ),
                  ],
                ),
              );
            }),
    );
  }
}

/// Penyedia porsi terjual UNTUK layar ini — `topLimit: 100` (cakupan PENUH
/// produksi, ~58 menu total, bukan sampel top-N) dipakai HANYA untuk dampak
/// gabungan tertimbang [computeWeightedHppImpact]. SENGAJA provider
/// TERPISAH dari `stockTopSellingItemsProvider` milik Task 7
/// (`topLimit: 30`, dipakai untuk mengurutkan `RecipeListScreen`) — memakai
/// ulang provider Task 7 di sini akan diam-diam membuang quantity menu di
/// luar 30 besar dan merusak rata-rata tertimbang (lihat komentar
/// `eligibleHppImpactInputs` di `stock_view.dart`). `autoDispose` sama pola
/// dengan `stockTopSellingItemsProvider`.
final hppImpactTopSellingItemsProvider = FutureProvider.autoDispose<List<TopItem>>((ref) async {
  final report = await ref
      .watch(adminReportRepositoryProvider)
      .fetchSales(range: '30d', topLimit: 100);
  return report.topItems;
});

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.withRecipe, required this.total, required this.impact});

  final int withRecipe;
  final int total;
  final WeightedHppImpact impact;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cakupan resep', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('$withRecipe dari $total menu sudah punya resep'),
          const Divider(height: 24),
          Text(
            'Dampak gabungan (ditimbang porsi terjual)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (impact.weightedDelta == null)
            Text(
              'Belum cukup data — belum ada menu dengan resep & HPP lama yang '
              'juga terjual dalam 30 hari terakhir.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            )
          else ...[
            Text(
              'Rata-rata tertimbang: ${Formatters.rupiah(impact.weightedDelta!)} / porsi',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: impact.weightedDelta! > 0
                        ? AppColors.error
                        : (impact.weightedDelta! < 0
                            ? AppColors.success
                            : AppColors.textPrimary),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dihitung dari ${impact.menuCount} menu (punya resep, HPP lama, '
              'dan terjual dalam 30 hari terakhir).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris menu — tampilan BERBEDA total antar
/// [HppRowVisualState.noRecipe] / [HppRowVisualState.noStoredPrice] /
/// [HppRowVisualState.compared], lihat [_HppRowBody]. Ketuk baris untuk
/// membuka Entri Resep (Task 7) menu ini — termasuk untuk baris "belum ada
/// resep", persis ajakan yang diminta brief ("tap → recipe entry").
class _HppRowTile extends StatelessWidget {
  const _HppRowTile({required this.row});
  final HppRow row;

  @override
  Widget build(BuildContext context) {
    final state = hppRowVisualState(row);
    return NeuCard(
      padding: EdgeInsets.zero,
      // Sama alasan dengan RecipeListScreen: ListTile/InkWell butuh
      // Material ANCESTOR miliknya sendiri, bukan "menembus" DecoratedBox
      // NeuCard sampai ke Material Scaffold yang jauh di atas.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.pushNamed(
            RouteNames.stockRecipe,
            pathParameters: {'menuItemId': row.menuItemId},
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(row.name, style: Theme.of(context).textTheme.titleSmall),
                    ),
                    const SizedBox(width: 8),
                    _StateBadge(state: state, row: row),
                  ],
                ),
                const SizedBox(height: 8),
                _HppRowBody(state: state, row: row),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state, required this.row});
  final HppRowVisualState state;
  final HppRow row;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case HppRowVisualState.noRecipe:
        return _Badge(text: 'Belum ada resep', color: AppColors.textSecondary);
      case HppRowVisualState.noStoredPrice:
        return const _Badge(text: 'Belum ada HPP lama', color: AppColors.amber);
      case HppRowVisualState.compared:
        final delta = row.delta ?? 0;
        if (delta > 0) return const _Badge(text: 'HPP lebih tinggi', color: AppColors.error);
        if (delta < 0) return const _Badge(text: 'HPP lebih rendah', color: AppColors.success);
        return const _Badge(text: 'Sama persis', color: AppColors.success);
    }
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

/// Isi baris — TIGA bentuk STRUKTURAL berbeda, bukan sekadar teks berbeda:
/// [HppRowVisualState.noRecipe] TIDAK punya angka HPP sama sekali;
/// [HppRowVisualState.noStoredPrice] punya HPP terhitung TAPI baris
/// "Selisih" digantikan pesan abu-abu miring; [HppRowVisualState.compared]
/// SATU-SATUNYA yang menampilkan baris "Selisih" tebal — termasuk saat
/// nilainya `Rp0`/`0%` (data sah, bukan placeholder).
class _HppRowBody extends StatelessWidget {
  const _HppRowBody({required this.state, required this.row});
  final HppRowVisualState state;
  final HppRow row;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case HppRowVisualState.noRecipe:
        return Text(
          'Belum ada resep — ketuk untuk menambahkan.',
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        );
      case HppRowVisualState.noStoredPrice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panas: ${Formatters.rupiah(row.computedHot)}   '
              'Dingin: ${Formatters.rupiah(row.computedIced)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Belum ada HPP lama untuk dibandingkan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        );
      case HppRowVisualState.compared:
        final delta = row.delta ?? 0;
        final pct = row.pct ?? 0;
        final deltaColor =
            delta > 0 ? AppColors.error : (delta < 0 ? AppColors.success : AppColors.textPrimary);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panas: ${Formatters.rupiah(row.computedHot)}   '
              'Dingin: ${Formatters.rupiah(row.computedIced)}',
            ),
            Text('HPP lama (cost_price): ${Formatters.rupiah(row.storedCostPrice ?? 0)}'),
            const SizedBox(height: 4),
            Text(
              'Selisih: ${Formatters.rupiah(delta)} (${pct.toStringAsFixed(1)}%)',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: deltaColor),
            ),
          ],
        );
    }
  }
}
