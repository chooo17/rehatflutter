import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../data/order_repository.dart';
import 'widgets/active_order_tracker.dart';

/// Layar "Lacak Pesanan": seluruh pesanan pengguna beserta progres tahapnya.
/// Pesanan yang masih berjalan ditaruh paling atas. Auto-refresh cepat +
/// menyegarkan seketika saat aplikasi kembali ke depan.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(ordersTrackingProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ordersTrackingProvider);
    // Pertahankan data lama saat refresh → tidak ada kedipan spinner.
    final cached = async.valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Lacak Pesanan')),
      body: Builder(
        builder: (context) {
          // Spinner HANYA pada muat pertama (belum ada data sama sekali).
          if (cached == null) {
            if (async.hasError) {
              return _Empty(
                icon: Icons.wifi_off_rounded,
                title: 'Gagal memuat pesanan',
                subtitle: 'Periksa koneksi lalu coba lagi.',
                onRetry: () => ref.invalidate(ordersTrackingProvider),
              );
            }
            return const Center(
                child: CircularProgressIndicator(color: AppColors.amber));
          }
          final orders = cached;
          if (orders.isEmpty) {
            return const _Empty(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada pesanan',
              subtitle: 'Pesananmu akan muncul di sini untuk dilacak.',
            );
          }
          // Pesanan berjalan diurut FIFO (paling dulu dibuat di atas) supaya
          // antrean dikerjakan urut masuk. Riwayat tetap terbaru dulu.
          final active = orders
              .where((o) => kActiveOrderStatuses.contains(o.status))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final past = orders
              .where((o) => !kActiveOrderStatuses.contains(o.status))
              .toList();

          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(ordersTrackingProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionLabel('Sedang berjalan (${active.length})'),
                  const SizedBox(height: 10),
                  ResponsiveGrid(

                    minItemWidth: 380,

                    maxColumns: 3,

                    runSpacing: 10,

                    children: [

                      for (final o in active)

                        OrderTrackCard(
                      order: o,
                      onTap: () => context.pushNamed(
                        RouteNames.orderDetail,
                        pathParameters: {'id': o.id},
                      ),
                    ),

                    ],

                  ),

                  const SizedBox(height: 10),
                  const SizedBox(height: 12),
                ],
                if (past.isNotEmpty) ...[
                  const _SectionLabel('Riwayat'),
                  const SizedBox(height: 10),
                  ResponsiveGrid(

                    minItemWidth: 380,

                    maxColumns: 3,

                    runSpacing: 10,

                    children: [

                      for (final o in past)

                        OrderTrackCard(
                      order: o,
                      onTap: () => context.pushNamed(
                        RouteNames.orderDetail,
                        pathParameters: {'id': o.id},
                      ),
                    ),

                    ],

                  ),

                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.amberDark,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ],
        ),
      ),
    );
  }
}
