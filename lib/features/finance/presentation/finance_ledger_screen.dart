import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../application/finance_ledger_view.dart';
import '../data/finance_repository.dart';

/// Layar Buku Besar (Task 8) — riwayat mutasi `finance_ledger` per pos, khusus
/// pemilik. Dijangkau dari Ringkasan Keuangan lewat ikon buku di AppBar.
///
/// **Paginasi**: kursor keyset komposit (`before` + `before_id`) diteruskan
/// APA ADANYA dari respons (`LedgerPage.nextBefore`/`nextBeforeId`) lewat
/// [appendLedgerPage] — TIDAK PERNAH disusun dari item terakhir (lihat
/// catatan bahaya di `finance_ledger_view.dart`). Saat filter pos berganti,
/// state (termasuk cursor) di-reset total.
class FinanceLedgerScreen extends ConsumerStatefulWidget {
  const FinanceLedgerScreen({super.key});

  @override
  ConsumerState<FinanceLedgerScreen> createState() => _FinanceLedgerScreenState();
}

class _FinanceLedgerScreenState extends ConsumerState<FinanceLedgerScreen> {
  LedgerListState _state = LedgerListState.initial;

  /// Filter yang menghasilkan [_state] saat ini — dipakai untuk mendeteksi
  /// pergantian filter pos (yang wajib me-reset cursor, lihat kontrak di
  /// `finance_ledger_view.dart`).
  String? _stateBucket;
  bool _loadingMore = false;
  String? _loadMoreError;

  /// Menerima halaman PERTAMA dari [ledgerProvider] (dipicu ulang otomatis
  /// oleh Riverpod tiap [ledgerBucketFilterProvider] berubah) dan
  /// menggantikan [_state] sepenuhnya — bukan APPEND — karena ini selalu
  /// representasi ulang dari awal untuk filter [bucket] saat ini.
  void _onFirstPage(String? bucket, LedgerPage page) {
    if (!mounted) return;
    setState(() {
      _stateBucket = bucket;
      _state = firstPageState(page);
      _loadMoreError = null;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !canLoadMore(_state)) return;
    // Dibaca SEBELUM await — filter pos bisa berganti sementara request ini
    // masih di jalan (lihat isLoadMoreResponseStale).
    final requestedBucket = ref.read(ledgerBucketFilterProvider);
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final repo = ref.read(financeRepositoryProvider);
      final page = await repo.fetchLedger(
        bucket: requestedBucket,
        before: _state.nextBefore,
        beforeId: _state.nextBeforeId,
      );
      if (!mounted) return;
      // Buang respons basi (filter sudah berganti sejak request dikirim) —
      // JANGAN append. Selain merusak tampilan filter baru dengan baris
      // filter lama, cursor filter baru juga akan tertimpa cursor posisi
      // filter lama, membuat baris filter baru terlewat permanen.
      final stale = isLoadMoreResponseStale(
        requestedBucket: requestedBucket,
        currentFilterBucket: ref.read(ledgerBucketFilterProvider),
        stateBucket: _stateBucket,
      );
      setState(() {
        _loadingMore = false;
        if (!stale) {
          _state = appendLedgerPage(_state, page);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = 'Gagal memuat halaman berikutnya. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bucket = ref.watch(ledgerBucketFilterProvider);
    final async = ref.watch(ledgerProvider);

    // Halaman pertama baru datang (mis. saat filter berganti) → gantikan
    // state lokal. Dijalankan di luar fase build lewat listener supaya tidak
    // memicu setState() saat sedang membangun widget.
    ref.listen<AsyncValue<LedgerPage>>(ledgerProvider, (previous, next) {
      next.whenData((page) => _onFirstPage(ref.read(ledgerBucketFilterProvider), page));
    });

    // C2 — cache hangat: `ledgerProvider` adalah FutureProvider BIASA (bukan
    // autoDispose), jadi kunjungan KEDUA ke layar ini (mis. pop lalu push
    // lagi) bisa menemukan provider SUDAH `AsyncData` dari kunjungan
    // sebelumnya. `ref.listen` di atas TIDAK menyala untuk nilai yang sudah
    // tersedia sebelum listener dipasang (hanya untuk transisi BARU) —
    // sehingga tanpa baris ini, `_state` tetap kosong (`_stateBucket ==
    // null`, `initState` baru) walau datanya sudah ada, dan layar tampil
    // "Belum ada mutasi" padahal data ada. Diseed langsung di sini
    // (bukan setState — kita masih di tengah build ini, jadi cukup ubah
    // field lalu lanjutkan build dgn nilai baru) memakai fungsi murni yang
    // sama dgn `_onFirstPage` supaya perilakunya identik (reset total, tidak
    // pernah gabung dgn state filter lain).
    if (_stateBucket != bucket) {
      final cached = async.valueOrNull;
      if (cached != null) {
        _stateBucket = bucket;
        _state = firstPageState(cached);
        _loadMoreError = null;
      }
    }

    // Pola keep-previous-data: spinner HANYA saat filter ini belum pernah
    // punya data sama sekali. Saat berganti filter, daftar lama (filter
    // sebelumnya) tetap tampil sampai halaman baru datang lewat listener di
    // atas — supaya layar tak berkedip kosong.
    final hasDataForCurrentFilter = _stateBucket == bucket;
    final showInitialSpinner = !hasDataForCurrentFilter && async.isLoading;
    final showInitialError = !hasDataForCurrentFilter && async.hasError;

    return Scaffold(
      appBar: AppBar(title: const Text('Buku Besar')),
      body: Column(
        children: [
          _BucketFilterBar(
            active: bucket,
            onPick: (b) => ref.read(ledgerBucketFilterProvider.notifier).state = b,
          ),
          const Divider(height: 1),
          Expanded(
            child: showInitialSpinner
                ? const Center(child: CircularProgressIndicator())
                : showInitialError
                    ? RefreshIndicator(
                        onRefresh: () async => ref.invalidate(ledgerProvider),
                        child: ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
                              child: Text(
                                'Gagal memuat buku besar. Tarik untuk mencoba lagi.',
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
                    : RefreshIndicator(
                        // Sengaja kembali ke halaman 1 (bukan me-refresh
                        // in-place lalu mempertahankan halaman 2..N yang
                        // sudah dimuat) — tarik-untuk-refresh adalah aksi
                        // "mulai ulang dari data terbaru", dan `ledgerProvider`
                        // hanya pernah menyimpan halaman pertama; halaman
                        // lanjutan dikelola terpisah oleh `_state` (lihat
                        // `_onFirstPage`), yang di-reset total begitu halaman
                        // 1 baru ini tiba.
                        onRefresh: () async => ref.invalidate(ledgerProvider),
                        child: _LedgerList(
                          state: _state,
                          loadingMore: _loadingMore,
                          loadMoreError: _loadMoreError,
                          onLoadMore: _loadMore,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _BucketFilterBar extends StatelessWidget {
  const _BucketFilterBar({required this.active, required this.onPick});

  final String? active;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('Semua'),
              selected: active == null,
              onSelected: (_) => onPick(null),
            ),
          ),
          for (final key in bucketFilterKeys)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(bucketLabel(key)),
                selected: active == key,
                onSelected: (_) => onPick(key),
              ),
            ),
        ],
      ),
    );
  }
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({
    required this.state,
    required this.loadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
  });

  final LedgerListState state;
  final bool loadingMore;
  final String? loadMoreError;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
            child: Text(
              'Belum ada mutasi untuk filter ini.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == state.items.length) {
          return _LoadMoreFooter(
            canLoadMore: canLoadMore(state),
            loading: loadingMore,
            error: loadMoreError,
            onPressed: onLoadMore,
          );
        }
        return _LedgerRow(entry: state.items[i]);
      },
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final inflow = isInflow(entry.direction);
    final amountColor = inflow ? AppColors.success : AppColors.error;
    return NeuCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                bucketLabel(entry.bucket),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              signedAmountLabel(entry),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: amountColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _DirectionBadge(direction: entry.direction),
                const SizedBox(width: 8),
                Text(sourceLabel(entry.source)),
                const Text(' · '),
                Text(Formatters.tanggalJam(entry.createdAt)),
              ],
            ),
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.note,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({required this.direction});

  /// `entry.direction` mentah — dipakai langsung (lewat [isInflow] &
  /// [directionLabel]) supaya tak ada perjalanan bool→string→bool yang tak
  /// perlu (dulu: `directionLabel(inflow ? 'in' : 'out')`).
  final String direction;

  @override
  Widget build(BuildContext context) {
    final inflow = isInflow(direction);
    final color = inflow ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        directionLabel(direction),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.canLoadMore,
    required this.loading,
    required this.error,
    required this.onPressed,
  });

  final bool canLoadMore;
  final bool loading;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!canLoadMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Sudah menampilkan semua mutasi.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: NeuButton(
              onPressed: loading ? null : onPressed,
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Muat lebih banyak'),
            ),
          ),
        ],
      ),
    );
  }
}
