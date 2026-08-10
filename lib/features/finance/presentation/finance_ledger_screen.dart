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

  /// `true` sejak halaman pertama PERTAMA KALI diterima (lihat
  /// [_onFirstPage]). **Final whole-branch review, C-3:** dulu
  /// "punya-data-untuk-filter-ini" hanya dicek lewat `_stateBucket == bucket`
  /// — pada render PERTAMA `_stateBucket` masih `null` dan filter default
  /// JUGA `null`, jadi `null == null` bernilai `true` walau `_state` masih
  /// kosong sama sekali (request halaman 1 belum selesai). Akibatnya layar
  /// langsung menyatakan "Belum ada mutasi untuk filter ini." selama seluruh
  /// durasi request pertama, bukan menampilkan spinner. Flag terpisah ini
  /// tak mungkin `true` secara kebetulan sebelum data sungguhan tiba.
  bool _hasEverLoaded = false;

  /// Generasi (epoch) halaman pertama yang SEDANG ditampilkan. Naik setiap
  /// [_onFirstPage] dijalankan (filter berganti ATAU tarik-untuk-refresh
  /// dengan filter sama) — lihat [isLoadMoreResponseStale].
  /// Ini satu-satunya cara membedakan "refresh dengan filter sama" dari
  /// "tidak ada perubahan sama sekali" (C-3): perbandingan bucket saja buta
  /// terhadap kasus itu karena bucket-nya identik sebelum & sesudah refresh.
  int _epoch = 0;

  /// Menerima halaman PERTAMA dari [ledgerProvider] (dipicu ulang otomatis
  /// oleh Riverpod tiap [ledgerBucketFilterProvider] berubah, ATAU oleh
  /// `ref.invalidate(ledgerProvider)` saat tarik-untuk-refresh) dan
  /// menggantikan [_state] sepenuhnya — bukan APPEND — karena ini selalu
  /// representasi ulang dari awal untuk filter [bucket] saat ini.
  void _onFirstPage(String? bucket, LedgerPage page) {
    if (!mounted) return;
    setState(() {
      _stateBucket = bucket;
      _hasEverLoaded = true;
      _state = firstPageState(page);
      _loadMoreError = null;
      _epoch++;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !canLoadMore(_state)) return;
    // Dibaca SEBELUM await — filter pos & epoch bisa berubah sementara
    // request ini masih di jalan (lihat isLoadMoreResponseStale).
    final requestedBucket = ref.read(ledgerBucketFilterProvider);
    final requestedEpoch = _epoch;
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
      // Buang respons basi (filter ATAU epoch sudah berubah sejak request
      // dikirim) — JANGAN append. Selain merusak tampilan filter baru dengan
      // baris filter lama, cursor baru juga akan tertimpa cursor posisi
      // lama, membuat baris baru terlewat permanen (lihat C-2 & C-3).
      final stale = isLoadMoreResponseStale(
        requestedBucket: requestedBucket,
        currentFilterBucket: ref.read(ledgerBucketFilterProvider),
        stateBucket: _stateBucket,
        requestedEpoch: requestedEpoch,
        currentEpoch: _epoch,
      );
      setState(() {
        // _loadingMore SELALU dilepas, basi atau tidak — kalau tidak,
        // request berikutnya terkunci permanen oleh guard di baris pertama
        // method ini.
        _loadingMore = false;
        if (!stale) {
          _state = appendLedgerPage(_state, page);
        }
      });
    } catch (_) {
      if (!mounted) return;
      // Galat basi (filter/epoch sudah berubah sejak request dikirim) tidak
      // relevan lagi untuk tampilan saat ini — jangan tampilkan pesan merah
      // di daftar filter/generasi BARU untuk kegagalan yang sebenarnya
      // milik filter/generasi LAMA.
      final stale = isLoadMoreResponseStale(
        requestedBucket: requestedBucket,
        currentFilterBucket: ref.read(ledgerBucketFilterProvider),
        stateBucket: _stateBucket,
        requestedEpoch: requestedEpoch,
        currentEpoch: _epoch,
      );
      setState(() {
        _loadingMore = false;
        if (!stale) {
          _loadMoreError = 'Gagal memuat halaman berikutnya. Coba lagi.';
        }
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

    // (C-1/C-2, seed dihapus) `ledgerProvider` kini `autoDispose` (lihat
    // catatan di `finance_repository.dart`) — kunjungan berikutnya ke layar
    // ini SELALU memicu fetch baru & `ref.listen` di atas SELALU menyala
    // untuk mengisi `_state` lewat `_onFirstPage`. Tidak perlu (dan tidak
    // boleh) menyeed `_state` langsung dari `async.valueOrNull` di sini —
    // itu bisa berupa data filter LAMA yang bertahan di cache Riverpod,
    // bukan filter yang sedang aktif (`bucket`).

    // Spinner HANYA saat filter ini belum pernah punya data sama sekali
    // (`_stateBucket != bucket`, mis. filter baru dipilih). Saat GANTI
    // FILTER, layar sengaja menampilkan spinner penuh layar (daftar lama
    // milik filter LAIN, tidak relevan untuk ditampilkan sambil menunggu).
    // Pola keep-previous-data berlaku untuk kasus REFRESH: filter sama
    // (`_stateBucket == bucket`) sehingga `hasDataForCurrentFilter` true dan
    // daftar lama tetap tampil sampai halaman baru datang lewat listener di
    // atas — layar tak berkedip kosong saat tarik-untuk-refresh.
    final hasDataForCurrentFilter = _hasEverLoaded && _stateBucket == bucket;
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
      key: Key('ledger-entry-${entry.id}'),
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
