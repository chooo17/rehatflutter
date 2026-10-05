import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/models/banner_model.dart';
import '../../../../shared/widgets/web_safe_image.dart';
import '../../../banners/data/banner_repository.dart';

/// Carousel banner promo di beranda. Menyembunyikan diri bila tak ada banner
/// (mis. belum ada isian / migrasi belum jalan) sehingga beranda tetap utuh.
class BannerCarousel extends ConsumerWidget {
  const BannerCarousel(
      {super.key, this.height, this.inset = 20, this.topGap = 20});

  /// Tinggi tetap (mis. hero desktop yang disejajarkan dgn kolom samping).
  /// `null` = ikut lebar (lihat [_CarouselState.build]).
  final double? height;

  /// Jarak kiri-kanan kartu banner.
  final double inset;

  /// Jarak di atas carousel.
  final double topGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(activeBannersProvider).valueOrNull ?? const [];
    if (banners.isEmpty) return const SizedBox.shrink();
    return _Carousel(
        banners: banners, height: height, inset: inset, topGap: topGap);
  }
}

class _Carousel extends StatefulWidget {
  const _Carousel({
    required this.banners,
    required this.height,
    required this.inset,
    required this.topGap,
  });
  final List<BannerModel> banners;
  final double? height;
  final double inset;
  final double topGap;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) _startAuto();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.banners.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: widget.topGap),
        SizedBox(
          // Tinggi ikut lebar (±3,2:1). Dulu tetap 130 → di layar lebar banner
          // jadi pita tipis ±10:1 dan gambar terpotong parah. Batas bawah 130
          // menjaga tampilan HP; batas atas 240 agar tak mendominasi layar.
          height: widget.height ??
              ((MediaQuery.sizeOf(context).width - 2 * widget.inset) / 3.2)
                  .clamp(130.0, 240.0),
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.inset),
              child: _BannerCard(banner: widget.banners[i]),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.amber : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});
  final BannerModel banner;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.goNamed(RouteNames.menu),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Latar: gambar bila ada, atau gradien brand.
            if (banner.hasImage)
              WebSafeImage(
                url: banner.imageUrl!,
                fit: BoxFit.cover,
                placeholder: Container(color: AppColors.crema),
                error: const _GradientBg(),
              )
            else
              const _GradientBg(),
            // Overlay gelap agar teks terbaca di atas gambar.
            if (banner.hasImage)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xCC000000), Color(0x22000000)],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleLarge
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBg extends StatelessWidget {
  const _GradientBg();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1C10), Color(0xFF8F5E26)],
        ),
      ),
    );
  }
}
