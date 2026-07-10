import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Animasi "lempar ke keranjang": gelembung gambar item terbang membentuk
/// busur dari tombol tambah menuju ikon keranjang aktif.
///
/// Ikon keranjang mendaftarkan [GlobalKey]-nya lewat [registerCartTarget].
/// Karena beberapa tab hidup bersamaan di IndexedStack (Beranda & Menu),
/// bisa ada >1 target — semuanya berada di posisi app-bar yang sama, jadi
/// kita ambil yang terdaftar paling akhir (route teratas menang).
final List<GlobalKey> _cartTargets = <GlobalKey>[];

void registerCartTarget(GlobalKey key) {
  if (!_cartTargets.contains(key)) _cartTargets.add(key);
}

void unregisterCartTarget(GlobalKey key) => _cartTargets.remove(key);

RenderBox? _resolveTargetBox() {
  for (final key in _cartTargets.reversed) {
    final obj = key.currentContext?.findRenderObject();
    if (obj is RenderBox && obj.attached && obj.hasSize) return obj;
  }
  return null;
}

/// Memicu animasi terbang dari [source] (biasanya tombol +) ke ikon keranjang.
/// Aman dipanggil kapan saja; menjadi no-op bila posisi tak bisa ditentukan.
void flyToCart(BuildContext source, {String? imageUrl}) {
  final overlay = Overlay.maybeOf(source, rootOverlay: true);
  final srcObj = source.findRenderObject();
  final targetBox = _resolveTargetBox();
  if (overlay == null ||
      srcObj is! RenderBox ||
      !srcObj.attached ||
      !srcObj.hasSize ||
      targetBox == null) {
    return;
  }
  final start = srcObj.localToGlobal(srcObj.size.center(Offset.zero));
  final end = targetBox.localToGlobal(targetBox.size.center(Offset.zero));

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingItem(
      start: start,
      end: end,
      imageUrl: imageUrl,
      onDone: entry.remove,
    ),
  );
  overlay.insert(entry);
}

class _FlyingItem extends StatefulWidget {
  const _FlyingItem({
    required this.start,
    required this.end,
    required this.imageUrl,
    required this.onDone,
  });

  final Offset start;
  final Offset end;
  final String? imageUrl;
  final VoidCallback onDone;

  @override
  State<_FlyingItem> createState() => _FlyingItemState();
}

class _FlyingItemState extends State<_FlyingItem>
    with SingleTickerProviderStateMixin {
  static const double _size = 46;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Kurva Bezier kuadratik dengan titik kontrol di atas → lintasan melengkung.
  Offset _bezier(double t) {
    final p0 = widget.start;
    final p2 = widget.end;
    final ctrl = Offset(
      (p0.dx + p2.dx) / 2,
      math.min(p0.dy, p2.dy) - 110,
    );
    final u = 1 - t;
    return p0 * (u * u) + ctrl * (2 * u * t) + p2 * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final pos = _bezier(Curves.easeInCubic.transform(t));
        final scale = lerpDouble(1, 0.35, Curves.easeIn.transform(t))!;
        final opacity =
            t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
        return Positioned(
          left: pos.dx - _size / 2,
          top: pos.dy - _size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: _bubble()),
            ),
          ),
        );
      },
    );
  }

  Widget _bubble() {
    final img = widget.imageUrl;
    const fallback =
        Icon(Icons.local_cafe_rounded, color: AppColors.amber, size: 24);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: AppColors.crema,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: (img == null || img.isEmpty)
          ? fallback
          : CachedNetworkImage(
              imageUrl: img,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}
