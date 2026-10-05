import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/customization_labels.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../../shared/models/review_model.dart';
import '../../../shared/widgets/cart_fly.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../auth/application/auth_controller.dart';
import '../../favorites/presentation/widgets/favorite_button.dart';
import '../../review/data/review_repository.dart';
import '../application/cart_controller.dart';
import '../data/menu_repository.dart';
import 'widgets/cart_icon_button.dart';

/// Detail item menu: pilih ukuran/suhu/gula, jumlah, lalu tambah ke keranjang.
class MenuDetailScreen extends ConsumerWidget {
  const MenuDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(menuDetailProvider(id));

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(menuDetailProvider(id)),
        ),
        data: (item) => _DetailBody(item: item),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.item});
  final MenuItemModel item;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  String? _size;
  String? _temperature;
  int? _sugarLevel;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    final o = widget.item.options;
    // Ukuran dihilangkan (produk hanya 1 ukuran) → tak dikirim ke pesanan.
    _size = null;
    _temperature = o.temperatures.isNotEmpty ? o.temperatures.first : null;
    _sugarLevel =
        o.sugarLevels.isNotEmpty ? _defaultSugar(o.sugarLevels) : null;
  }

  int _defaultSugar(List<int> levels) =>
      levels.contains(100) ? 100 : levels.first;

  int get _total => widget.item.price * _qty;

  void _addToCart(BuildContext source) {
    // Terbangkan dulu (posisi dihitung sinkron sebelum layar di-pop).
    flyToCart(source, imageUrl: widget.item.imageUrl);
    ref.read(cartControllerProvider.notifier).add(
          widget.item,
          size: _size,
          temperature: _temperature,
          sugarLevel: _sugarLevel,
          quantity: _qty,
        );
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$_qty x ${widget.item.name} ditambahkan ke keranjang'),
      ));
  }

  List<Widget> _actions(MenuItemModel item, bool isGuest) => isGuest
      ? [CartIconButton(color: AppColors.espresso)]
      : [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FavoriteButton(item: item, size: 24),
          ),
          CartIconButton(color: AppColors.espresso),
        ];

  /// Nama, harga, deskripsi, opsi, jumlah, ulasan — dipakai kedua tata letak.
  Widget _details(MenuItemModel item) {
    final o = item.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(item.name, style: AppTextStyles.displayMedium),
            ),
            if (item.rating != null) ...[
              const Icon(Icons.star_rounded, color: AppColors.amber, size: 20),
              const SizedBox(width: 4),
              Text(item.rating!.toStringAsFixed(1), style: AppTextStyles.label),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          Formatters.rupiah(item.price),
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.amberDark),
        ),
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(item.description,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.6)),
        ],
        // Ukuran dihilangkan — produk hanya tersedia 1 ukuran.
        // Suhu ------------------------------------------------
        if (o.temperatures.isNotEmpty) ...[
          const SizedBox(height: 24),
          _label('Suhu'),
          const SizedBox(height: 10),
          _chips(
            values: o.temperatures,
            selected: _temperature,
            labelOf: CustomizationLabels.temperature,
            onTap: (v) => setState(() => _temperature = v),
          ),
        ],
        // Gula ------------------------------------------------
        if (o.sugarLevels.isNotEmpty) ...[
          const SizedBox(height: 24),
          _label('Tingkat gula'),
          const SizedBox(height: 10),
          _chips(
            values: o.sugarLevels,
            selected: _sugarLevel,
            labelOf: (v) => v == 0 ? 'Tanpa gula' : '$v%',
            onTap: (v) => setState(() => _sugarLevel = v),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            _label('Jumlah'),
            const Spacer(),
            _QtyStepper(
              quantity: _qty,
              onChanged: (v) => setState(() => _qty = v),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _ReviewsSection(itemId: item.id),
      ],
    );
  }

  Widget _bottomBar(MenuItemModel item) {
    return NeuBottomBar(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              Text(Formatters.rupiah(_total), style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Builder(
              builder: (btnContext) => NeuButton(
                expand: true,
                accent: item.isAvailable,
                onPressed:
                    item.isAvailable ? () => _addToCart(btnContext) : null,
                child: Text(
                  item.isAvailable ? 'Tambah ke Keranjang' : 'Habis',
                  style: AppTextStyles.button.copyWith(
                      color: item.isAvailable
                          ? Colors.white
                          : AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isGuest = ref.watch(isGuestProvider);

    // Layar lebar: dua panel — foto besar di kiri, opsi + tombol tambah di
    // kanan — bukan foto pita + kolom opsi yang melar selebar layar.
    if (MediaQuery.sizeOf(context).width >= 900) {
      return SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _HeaderImage(url: item.imageUrl),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      width: 56,
                      height: 56,
                      child: _circleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _actions(item, isGuest),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 32, 24),
                      child: _details(item),
                    ),
                  ),
                  _bottomBar(item),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: AppColors.backgroundLight,
              foregroundColor: AppColors.espresso,
              leading: _circleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
              // Tamu tak punya favorit → sembunyikan; keranjang tetap ada.
              actions: _actions(item, isGuest),
              flexibleSpace: FlexibleSpaceBar(
                background: _HeaderImage(url: item.imageUrl),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: _details(item),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _bottomBar(item),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text, style: AppTextStyles.titleMedium);

  /// Baris chip generik untuk opsi (ukuran/suhu/gula).
  Widget _chips<T>({
    required List<T> values,
    required T? selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onTap,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final v in values)
          GestureDetector(
            onTap: () => onTap(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: v == selected ? AppColors.espresso : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        v == selected ? AppColors.espresso : AppColors.border),
              ),
              child: Text(
                labelOf(v),
                style: AppTextStyles.caption.copyWith(
                  color:
                      v == selected ? AppColors.crema : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: 20, color: AppColors.espresso),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.quantity, required this.onChanged});
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _btn(Icons.remove_rounded,
              quantity > 1 ? () => onChanged(quantity - 1) : null),
          SizedBox(
            width: 36,
            child: Text('$quantity',
                textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
          ),
          _btn(Icons.add_rounded, () => onChanged(quantity + 1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 20,
            color: onTap == null ? AppColors.border : AppColors.espresso),
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: AppColors.crema,
        child: const Center(
            child: Icon(Icons.local_cafe_rounded,
                color: AppColors.amber, size: 64)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      // Header lebar penuh — batasi decode ~800px (cukup untuk layar terpadat).
      memCacheWidth: 800,
      placeholder: (_, __) => Container(color: AppColors.crema),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.crema,
        child: const Center(
            child: Icon(Icons.local_cafe_rounded,
                color: AppColors.amber, size: 64)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text('Gagal memuat detail menu.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

/// Bagian ulasan pada detail menu (rata-rata + daftar).
class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemReviewsProvider(itemId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ulasan', style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: AppColors.amber))),
          ),
          error: (e, _) =>
              Text('Gagal memuat ulasan.', style: AppTextStyles.bodySmall),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text('Belum ada ulasan untuk menu ini.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary));
            }
            return Column(
              children: [
                for (var i = 0; i < reviews.length && i < 5; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _ReviewTile(review: reviews[i]),
                ],
                if (reviews.length > 5) ...[
                  const SizedBox(height: 8),
                  Text('+${reviews.length - 5} ulasan lainnya',
                      style: AppTextStyles.bodySmall),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.crema,
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Icon(Icons.person_rounded, color: AppColors.amberDark, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(review.userName,
                        style: AppTextStyles.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  StarRating(rating: review.rating.toDouble(), size: 14),
                ],
              ),
              if (review.comment.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(review.comment,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ],
              if (review.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(Formatters.tanggal(review.createdAt!),
                    style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
