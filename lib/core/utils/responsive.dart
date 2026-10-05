import 'package:flutter/widgets.dart';

/// Kelas ukuran layar untuk desain responsif.
enum DeviceType { mobile, tablet, desktop }

/// Breakpoints: mobile < 600, tablet 600–1024, desktop ≥ 1024.
DeviceType deviceTypeOf(double width) {
  if (width < 600) return DeviceType.mobile;
  if (width < 1024) return DeviceType.tablet;
  return DeviceType.desktop;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  DeviceType get deviceType => deviceTypeOf(screenWidth);
  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// Jumlah kolom grid menu berdasarkan lebar terpakai: 2 (mobile) /
  /// 3 (tablet) / 4 (desktop). Dihitung dari lebar render (dibatasi shell).
  int get menuColumns {
    final w = screenWidth;
    if (w < 600) return 2;
    if (w < 840) return 3;
    if (w < 1280) return 4;
    if (w < 1600) return 5;
    return 6;
  }
}

/// Membatasi konten satu-kolom (form, daftar) agar tak melebar di layar besar.
/// Di mobile tak berpengaruh; di tablet/desktop dipusatkan hingga [maxWidth].
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 600});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
