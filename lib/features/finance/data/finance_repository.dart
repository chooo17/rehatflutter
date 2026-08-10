import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/formatters.dart';

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _double(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

bool _bool(dynamic v) => v == true;

List<String> _stringList(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

/// Parse timestamp server sebagai UTC yang benar. Timestamp Postgres
/// (`timestamptz`) biasanya datang dengan penanda zona eksplisit (`Z` /
/// `+00:00`), tapi bila suatu saat tidak ada, `DateTime.parse` akan
/// membacanya sebagai waktu LOKAL perangkat alih-alih UTC — merusak
/// konversi WIB (`Formatters.toWib`) di layar. Helper ini memaksa hasil
/// selalu UTC.
final RegExp _hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

DateTime _utc(dynamic v) {
  final s = v?.toString();
  if (s == null || s.isEmpty) return DateTime.now().toUtc();
  // Tanpa penanda zona, DateTime.parse membaca string sebagai waktu LOKAL
  // perangkat — bukan yang kita mau untuk timestamp server. Tambahkan 'Z'
  // supaya string tanpa zona tetap ditafsirkan UTC, bukan dikonversi lewat
  // offset lokal perangkat (toUtc() pada DateTime non-UTC akan menggeser
  // jam, bukan sekadar menandainya UTC).
  final normalized = _hasTimezone.hasMatch(s) ? s : '${s}Z';
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return DateTime.now().toUtc();
  return parsed.isUtc ? parsed : parsed.toUtc();
}

/// Satu pos biaya tetap bulanan (sewa, gaji, listrik…).
class FixedCost {
  const FixedCost({
    required this.id,
    required this.name,
    required this.amount,
    this.category = '',
    this.dueDay,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int amount;
  final String category;
  final int? dueDay;
  final bool isActive;

  factory FixedCost.fromJson(Map<String, dynamic> j) => FixedCost(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        amount: _int(j['amount']),
        category: (j['category'] ?? '').toString(),
        dueDay: j['due_day'] == null ? null : _int(j['due_day']),
        isActive: j['is_active'] == null ? true : j['is_active'] == true,
      );
}

/// Laporan laba rugi satu bulan.
class ProfitLoss {
  const ProfitLoss({
    required this.month,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.fixedCosts,
    required this.variableExpenses,
    required this.paymentFees,
    required this.netProfit,
    required this.netMarginPct,
    required this.fixedCostItems,
    this.variableExpensesUnavailable = false,
  });

  final String month;
  final int revenue;
  final int cogs;
  final int grossProfit;
  final int grossMarginPct;
  final int fixedCosts;
  final int variableExpenses;
  final int paymentFees;
  final int netProfit;
  final int netMarginPct;
  final List<FixedCost> fixedCostItems;

  /// True bila query pengeluaran variabel (non-restock) gagal di backend —
  /// artinya [variableExpenses] (dan angka turunannya) DEFAULT 0, bukan
  /// data nyata. Layar wajib memperingatkan, bukan menampilkan Rp0 diam-diam.
  final bool variableExpensesUnavailable;

  factory ProfitLoss.fromJson(Map<String, dynamic> j) => ProfitLoss(
        month: (j['month'] ?? '').toString(),
        revenue: _int(j['revenue']),
        cogs: _int(j['cogs']),
        grossProfit: _int(j['grossProfit']),
        grossMarginPct: _int(j['grossMarginPct']),
        fixedCosts: _int(j['fixedCosts']),
        variableExpenses: _int(j['variableExpenses']),
        paymentFees: _int(j['paymentFees']),
        netProfit: _int(j['netProfit']),
        netMarginPct: _int(j['netMarginPct']),
        fixedCostItems: ((j['fixed_cost_items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FixedCost.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        variableExpensesUnavailable: j['variable_expenses_unavailable'] == true,
      );
}

/// Saldo lima amplop alokasi. Rupiah integer — **boleh negatif** (baris
/// shortfall & penarikan melebihi saldo memang diizinkan oleh backend;
/// jangan pernah di-clamp ke 0 di sini).
class BucketBalances {
  const BucketBalances({
    this.restock = 0,
    this.operational = 0,
    this.personal = 0,
    this.scaling = 0,
    this.emergency = 0,
  });

  final int restock;
  final int operational;
  final int personal;
  final int scaling;
  final int emergency;

  factory BucketBalances.fromJson(Map<String, dynamic> j) => BucketBalances(
        restock: _int(j['restock']),
        operational: _int(j['operational']),
        personal: _int(j['personal']),
        scaling: _int(j['scaling']),
        emergency: _int(j['emergency']),
      );
}

/// Rambu kesehatan kas — hasil kalkulator murni di backend (bukan kolom
/// DB), karenanya key JSON-nya **camelCase** (beda dari field lain yang
/// snake_case).
class FinanceGuards {
  const FinanceGuards({
    this.breakEvenDaily = 0,
    this.runwayDays = 0,
    this.emergencyPct = 0,
    this.personalWithdrawBlocked = false,
    this.emergencyReached = false,
  });

  final int breakEvenDaily;
  final int runwayDays;
  final int emergencyPct;
  final bool personalWithdrawBlocked;
  final bool emergencyReached;

  factory FinanceGuards.fromJson(Map<String, dynamic> j) => FinanceGuards(
        breakEvenDaily: _int(j['breakEvenDaily']),
        runwayDays: _int(j['runwayDays']),
        emergencyPct: _int(j['emergencyPct']),
        personalWithdrawBlocked: _bool(j['personalWithdrawBlocked']),
        emergencyReached: _bool(j['emergencyReached']),
      );
}

/// Pengaturan alokasi amplop (bisa diubah pemilik nanti — Tahap 3).
class FinanceSettings {
  const FinanceSettings({
    this.pctRestock = 0,
    this.operationalDaily = 0,
    this.emergencyTarget = 0,
    this.startedOn,
  });

  /// Pecahan (mis. 0.4 = 40%), bukan persen bulat.
  final double pctRestock;
  final int operationalDaily;
  final int emergencyTarget;
  final String? startedOn;

  factory FinanceSettings.fromJson(Map<String, dynamic> j) => FinanceSettings(
        pctRestock: _double(j['pct_restock']),
        operationalDaily: _int(j['operational_daily']),
        emergencyTarget: _int(j['emergency_target']),
        startedOn: j['started_on']?.toString(),
      );
}

/// Ringkasan amplop alokasi (`GET /admin/finance/overview`).
class FinanceOverview {
  const FinanceOverview({
    required this.balances,
    required this.guards,
    required this.settings,
    this.lastAllocatedDate,
    this.basis = '',
    this.basisMonth = '',
    this.insufficientData = false,
    this.marginNonPositive = false,
    this.variableExpensesUnavailable = false,
    this.missingAllocationDates = const [],
    this.missingAllocationCount = 0,
  });

  final BucketBalances balances;
  final FinanceGuards guards;
  final FinanceSettings settings;
  final String? lastAllocatedDate;

  /// `'previous'` (bulan lalu penuh) atau `'current_partial'` (bulan
  /// berjalan, data belum lengkap) — dasar perhitungan rambu.
  final String basis;

  /// `YYYY-MM` — bulan yang dipakai sebagai dasar [basis].
  final String basisMonth;

  /// Belum ada omzet sama sekali. `breakEvenDaily == 0` di kondisi ini
  /// BUKAN berarti target tercapai — datanya memang belum ada.
  final bool insufficientData;

  /// Ada omzet tapi margin ≤ 0 (jual rugi / margin dibulatkan jadi 0).
  /// `breakEvenDaily == 0` di kondisi ini juga tak bermakna.
  final bool marginNonPositive;

  /// Query pengeluaran variabel gagal di backend → biaya diremehkan,
  /// sehingga [FinanceGuards.runwayDays] bisa terlalu panjang & rem
  /// pribadi ([FinanceGuards.personalWithdrawBlocked]) bisa `false`
  /// padahal seharusnya `true`.
  final bool variableExpensesUnavailable;

  /// Tanggal (menaik) yang belum dialokasikan, maksimal 60 terbaru.
  final List<String> missingAllocationDates;

  /// Jumlah SEBENARNYA tanggal yang belum dialokasikan — bisa lebih besar
  /// dari `missingAllocationDates.length` (daftar dipotong 60).
  final int missingAllocationCount;

  factory FinanceOverview.fromJson(Map<String, dynamic> j) => FinanceOverview(
        balances: BucketBalances.fromJson(
            Map<String, dynamic>.from((j['balances'] as Map?) ?? const {})),
        guards: FinanceGuards.fromJson(
            Map<String, dynamic>.from((j['guards'] as Map?) ?? const {})),
        settings: FinanceSettings.fromJson(
            Map<String, dynamic>.from((j['settings'] as Map?) ?? const {})),
        lastAllocatedDate: j['last_allocated_date']?.toString(),
        basis: (j['basis'] ?? '').toString(),
        basisMonth: (j['basis_month'] ?? '').toString(),
        insufficientData: _bool(j['insufficient_data']),
        marginNonPositive: _bool(j['margin_non_positive']),
        variableExpensesUnavailable: _bool(j['variable_expenses_unavailable']),
        missingAllocationDates: _stringList(j['missing_allocation_dates']),
        missingAllocationCount: _int(j['missing_allocation_count']),
      );
}

/// Satu baris buku besar amplop (`GET /admin/finance/ledger`).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.bucket,
    required this.direction,
    required this.source,
    required this.amount,
    required this.note,
    required this.refDate,
    required this.createdAt,
    this.createdBy,
  });

  final String id;
  final String bucket;

  /// `'in'` atau `'out'`.
  final String direction;
  final String source;

  /// Rupiah integer — terbaca apa adanya, termasuk negatif.
  final int amount;
  final String note;

  /// `YYYY-MM-DD`.
  final String refDate;

  /// Selalu UTC (lihat [_utc]) — konversi tampilan HARUS lewat
  /// `Formatters.toWib`, jangan `DateFormat` langsung.
  final DateTime createdAt;
  final String? createdBy;

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: (j['id'] ?? '').toString(),
        bucket: (j['bucket'] ?? '').toString(),
        direction: (j['direction'] ?? '').toString(),
        source: (j['source'] ?? '').toString(),
        amount: _int(j['amount']),
        note: (j['note'] ?? '').toString(),
        refDate: (j['ref_date'] ?? '').toString(),
        createdAt: _utc(j['created_at']),
        createdBy: j['created_by']?.toString(),
      );
}

/// Satu halaman buku besar dengan kursor keyset komposit
/// (`created_at` + `id`) — WAJIB dipakai berpasangan & apa adanya dari
/// respons ini, jangan disusun ulang dari item terakhir (banyak baris
/// alokasi harian punya `created_at` identik).
class LedgerPage {
  const LedgerPage({
    this.items = const [],
    this.hasMore = false,
    this.nextBefore,
    this.nextBeforeId,
  });

  final List<LedgerEntry> items;
  final bool hasMore;
  final String? nextBefore;
  final String? nextBeforeId;

  factory LedgerPage.fromJson(Map<String, dynamic> j) => LedgerPage(
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        hasMore: _bool(j['has_more']),
        nextBefore: j['next_before']?.toString(),
        nextBeforeId: j['next_before_id']?.toString(),
      );
}

Map<String, dynamic> _unwrap(dynamic body) => (body is Map && body['data'] is Map)
    ? Map<String, dynamic>.from(body['data'] as Map)
    : Map<String, dynamic>.from(body as Map);

/// Akses modul keuangan (khusus pemilik). Endpoint membalas 404 untuk akun
/// lain — HANYA itu yang berarti "tidak punya akses". Kegagalan lain
/// (jaringan mati, timeout, sesi kedaluwarsa, server error) dilempar ulang
/// supaya pemanggil (FutureProvider) bisa membedakannya, alih-alih diam-diam
/// menyembunyikan menu Keuangan seolah pengguna memang tak berhak.
class FinanceRepository {
  FinanceRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  Future<bool> hasAccess() async {
    try {
      await _client.get<dynamic>(ApiConstants.financePing);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<List<FixedCost>> fetchFixedCosts() async {
    final res = await _client.get<dynamic>(ApiConstants.financeFixedCosts);
    final data = _unwrap(res.data);
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => FixedCost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addFixedCost({
    required String name,
    required int amount,
    String? category,
    int? dueDay,
  }) async {
    await _client.post<dynamic>(ApiConstants.financeFixedCosts, data: {
      'name': name.trim(),
      'amount': amount,
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
      if (dueDay != null) 'due_day': dueDay,
    });
  }

  Future<void> deleteFixedCost(String id) async {
    await _client.delete<dynamic>(ApiConstants.financeFixedCost(id));
  }

  Future<ProfitLoss> fetchPnl(String month) async {
    final res = await _client.get<dynamic>(
      ApiConstants.financePnl,
      query: {'month': month},
    );
    return ProfitLoss.fromJson(_unwrap(res.data));
  }

  Future<FinanceOverview> fetchOverview() async {
    final res = await _client.get<dynamic>(ApiConstants.financeOverview);
    return FinanceOverview.fromJson(_unwrap(res.data));
  }

  /// `before` (created_at ISO) dan `before_id` (uuid) membentuk kursor
  /// keyset komposit — backend membalas 400 `INVALID_CURSOR` bila hanya
  /// satu diisi. Divalidasi di sisi klien juga supaya kesalahan pemanggilan
  /// (bug di layar Task 7-8) ketahuan sebelum sampai ke jaringan.
  static void validateCursor({required String? before, required String? beforeId}) {
    final hasBefore = before != null && before.isNotEmpty;
    final hasBeforeId = beforeId != null && beforeId.isNotEmpty;
    if (hasBefore != hasBeforeId) {
      throw ArgumentError(
        'before dan before_id wajib berpasangan (isi keduanya atau kosongkan keduanya).',
      );
    }
  }

  Future<LedgerPage> fetchLedger({
    String? bucket,
    int limit = 20,
    String? before,
    String? beforeId,
  }) async {
    validateCursor(before: before, beforeId: beforeId);
    final res = await _client.get<dynamic>(
      ApiConstants.financeLedger,
      query: {
        if (bucket != null && bucket.isNotEmpty) 'bucket': bucket,
        'limit': limit,
        if (before != null) 'before': before,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
    return LedgerPage.fromJson(_unwrap(res.data));
  }

  /// Tarik dana dari satu amplop. Backend membalas 409 `DUPLICATE_WITHDRAWAL`
  /// bila penarikan identik diulang dalam 60 detik — biarkan
  /// [ApiException] menjalar ke pemanggil (kode ada di `ApiException.code`)
  /// supaya layar bisa menampilkan pesan yang sesuai, bukan pesan generik.
  Future<void> withdraw({
    required String bucket,
    required int amount,
    required String note,
  }) async {
    await _client.post<dynamic>(ApiConstants.financeWithdraw, data: {
      'bucket': bucket,
      'amount': amount,
      'note': note,
    });
  }

  /// Jalankan alokasi harian untuk [date] (`YYYY-MM-DD`). **Tanggal WAJIB
  /// diisi pemanggil** — endpoint backend defaultnya "hari ini" bila
  /// tanggal tak dikirim, dan default itu berbahaya (mengunci alokasi pada
  /// omzet hari yang belum selesai/parsial). Method ini sengaja tak punya
  /// nilai default supaya tak ada jalan diam-diam memakai default backend.
  Future<void> allocate(String date) async {
    await _client.post<dynamic>(ApiConstants.financeAllocate, data: {
      'date': date,
    });
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(client: ref.watch(dioClientProvider));
});

/// Apakah akun yang login boleh membuka modul keuangan.
final financeAccessProvider = FutureProvider<bool>((ref) {
  return ref.watch(financeRepositoryProvider).hasAccess();
});

final fixedCostsProvider = FutureProvider<List<FixedCost>>((ref) {
  return ref.watch(financeRepositoryProvider).fetchFixedCosts();
});

/// Bulan aktif laporan laba rugi (default: bulan berjalan menurut WIB).
final pnlMonthProvider = StateProvider<DateTime>((ref) {
  final now = Formatters.toWib(DateTime.now());
  return DateTime(now.year, now.month);
});

final pnlProvider = FutureProvider<ProfitLoss>((ref) {
  final m = ref.watch(pnlMonthProvider);
  final month =
      '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
  return ref.watch(financeRepositoryProvider).fetchPnl(month);
});

/// Ringkasan amplop alokasi (saldo lima bucket + rambu kesehatan kas).
final financeOverviewProvider = FutureProvider<FinanceOverview>((ref) {
  return ref.watch(financeRepositoryProvider).fetchOverview();
});

/// Filter bucket aktif di layar buku besar. `null` = semua bucket.
final ledgerBucketFilterProvider = StateProvider<String?>((ref) => null);

/// Halaman pertama buku besar sesuai [ledgerBucketFilterProvider].
/// Halaman berikutnya (kursor keyset `next_before`/`next_before_id`)
/// dikelola oleh layar (Task 7-8) lewat `FinanceRepository.fetchLedger`
/// langsung, bukan lewat provider ini.
final ledgerProvider = FutureProvider<LedgerPage>((ref) {
  final bucket = ref.watch(ledgerBucketFilterProvider);
  return ref.watch(financeRepositoryProvider).fetchLedger(bucket: bucket);
});
