import 'package:flutter/widgets.dart';

/// Kelas ukuran layar untuk desain responsif.
enum DeviceType { mobile, tablet, desktop }

/// Breakpoints: mobile < 600, tablet 600–1024, desktop ≥ 1024.
///
/// Di desktop navigasi utama pindah ke sidebar kiri (lihat `MainShell`) dan
/// layar memakai tata letak adaptif ([ResponsiveGrid], [ResponsiveListView],
/// [TwoPane]) — isi MENGISI lebar layar, bukan dibatasi kolom tengah dengan
/// ruang kosong di kiri-kanan.
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

  /// Jumlah kolom grid menu berdasarkan lebar terpakai.
  int get menuColumns {
    final w = screenWidth;
    if (w < 600) return 2;
    if (w < 840) return 3;
    if (w < 1280) return 4;
    if (w < 1600) return 5;
    return 6;
  }
}

/// Jumlah kolom agar tiap item minimal [minItemWidth] lebarnya (dibatasi
/// [maxColumns]). Selalu ≥ 1, jadi HP tetap satu kolom.
int columnsFor(double width,
    {required double minItemWidth, double spacing = 12, int maxColumns = 4}) {
  final cols = ((width + spacing) / (minItemWidth + spacing)).floor();
  return cols.clamp(1, maxColumns);
}

/// Baris berisi [cols] sel sama lebar; sel kosong diisi ruang agar kolom tetap
/// sejajar di baris terakhir. Tinggi sel dalam satu baris disamakan.
class _GridRow extends StatelessWidget {
  const _GridRow(
      {required this.cells, required this.cols, required this.spacing});

  final List<Widget> cells;
  final int cols;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (cols == 1) return cells.first;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < cols; k++) ...[
            if (k > 0) SizedBox(width: spacing),
            Expanded(child: k < cells.length ? cells[k] : const SizedBox()),
          ],
        ],
      ),
    );
  }
}

/// Daftar item yang menjadi grid N kolom di layar lebar (non-lazy, untuk
/// jumlah item kecil-menengah di dalam `ListView`/`Column`). Satu kolom di HP,
/// jadi tampilan mobile tak berubah.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 340,
    this.maxColumns = 4,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final cols = columnsFor(c.maxWidth,
          minItemWidth: minItemWidth, spacing: spacing, maxColumns: maxColumns);
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        if (i > 0) rows.add(SizedBox(height: runSpacing));
        final end = (i + cols).clamp(0, children.length);
        rows.add(_GridRow(
            cells: children.sublist(i, end), cols: cols, spacing: spacing));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      );
    });
  }
}

/// Pengganti `ListView.builder`/`ListView.separated` yang menyusun item jadi
/// N kolom di layar lebar — LAZY per baris, aman untuk daftar panjang &
/// paginasi (controller diteruskan apa adanya).
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.physics,
    this.minItemWidth = 340,
    this.maxColumns = 4,
    this.spacing = 12,
    this.runSpacing = 12,
    this.header,
    this.footer,
    this.separator,
    this.gridCell,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  /// Widget penuh-lebar sebelum/sesudah grid (judul seksi, spinner muat-lagi).
  final Widget? header;
  final Widget? footer;

  /// Pemisah antar-item saat SATU kolom (mis. `Divider` pada daftar baris
  /// polos). Diabaikan di mode grid.
  final Widget? separator;

  /// Pembungkus tiap sel saat MULTI-kolom — baris polos (tanpa kartu) perlu
  /// batas visual begitu disusun berdampingan.
  final Widget Function(Widget cell)? gridCell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final inset = padding?.resolve(Directionality.of(context));
      final w = c.maxWidth - (inset?.horizontal ?? 0);
      final cols = columnsFor(w,
          minItemWidth: minItemWidth, spacing: spacing, maxColumns: maxColumns);
      final rowCount = (itemCount / cols).ceil();
      final extra = (header != null ? 1 : 0) + (footer != null ? 1 : 0);
      return ListView.builder(
        controller: controller,
        physics: physics,
        padding: padding,
        itemCount: rowCount + extra,
        itemBuilder: (context, i) {
          if (header != null) {
            if (i == 0) return header!;
            i -= 1;
          }
          if (i >= rowCount) return footer!;
          final start = i * cols;
          final end = (start + cols).clamp(0, itemCount);
          if (cols == 1 && separator != null) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (i > 0) separator!,
                itemBuilder(context, start),
              ],
            );
          }
          Widget cell(int k) {
            final w = itemBuilder(context, k);
            return cols > 1 && gridCell != null ? gridCell!(w) : w;
          }

          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : runSpacing),
            child: _GridRow(
              cells: [for (var k = start; k < end; k++) cell(k)],
              cols: cols,
              spacing: spacing,
            ),
          );
        },
      );
    });
  }
}

/// Dua panel berdampingan di layar lebar (≥ [breakpoint]); bertumpuk
/// (primer di atas) di layar sempit. Panel sekunder lebarnya tetap
/// [secondaryWidth] — cocok untuk ringkasan/aksi di samping isi utama.
///
/// Mode lebar: kedua panel masing-masing digulir sendiri ([primary] &
/// [secondary] sebaiknya sudah berupa daftar yang bisa digulir).
/// Mode sempit: [narrow] dipakai bila diberikan (mis. satu ListView berisi
/// keduanya), selain itu keduanya ditumpuk dalam Column.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.narrow,
    this.breakpoint = 900,
    this.secondaryWidth = 380,
    this.divider,
  });

  final Widget primary;
  final Widget secondary;
  final Widget? narrow;
  final double breakpoint;
  final double secondaryWidth;
  final Widget? divider;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return narrow ??
            Column(children: [Expanded(child: primary), secondary]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: primary),
          if (divider != null) divider!,
          SizedBox(width: secondaryWidth, child: secondary),
        ],
      );
    });
  }
}

/// Membatasi konten satu-kolom (form) agar tak melebar di layar besar.
/// Di mobile tak berpengaruh; di tablet/desktop dipusatkan hingga [maxWidth].
///
/// [centerVertically]: di tablet/desktop (bukan mobile) konten dipusatkan
/// vertikal. `Align` memberi batas tinggi longgar, sehingga
/// `SingleChildScrollView` di dalamnya menyusut setinggi isi (terpusat) dan
/// tetap bisa digulir bila isi lebih tinggi dari layar. Mobile tetap rata atas.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.centerVertically = false,
  });

  final Widget child;
  final double maxWidth;
  final bool centerVertically;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centerVertically && !context.isMobile
          ? Alignment.center
          : Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Halaman berisi dua kelompok isi: di layar lebar (≥ [breakpoint])
/// berdampingan sebagai dua kolom yang digulir bersama; di layar sempit
/// ditumpuk ([left] lalu [right]) dalam satu daftar — urutan mobile tak berubah.
///
/// [leftWidth] tetap (mis. panel identitas/ringkasan) atau `null` = dibagi
/// rata dengan [leftFlex]/[rightFlex].
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 900,
    this.leftWidth,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.gap = 32,
    this.narrowPadding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.widePadding = const EdgeInsets.fromLTRB(32, 8, 32, 32),
    this.narrowGap = 24,
    this.controller,
    this.physics,
  });

  final List<Widget> left;
  final List<Widget> right;
  final double breakpoint;
  final double? leftWidth;
  final int leftFlex;
  final int rightFlex;
  final double gap;
  final EdgeInsetsGeometry narrowPadding;
  final EdgeInsetsGeometry widePadding;

  /// Jarak antara [left] & [right] saat ditumpuk (mobile).
  final double narrowGap;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return ListView(
          controller: controller,
          physics: physics,
          padding: narrowPadding,
          children: [
            ...left,
            if (left.isNotEmpty && right.isNotEmpty)
              SizedBox(height: narrowGap),
            ...right,
          ],
        );
      }
      Widget col(List<Widget> children) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
      return ListView(
        controller: controller,
        physics: physics,
        padding: widePadding,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leftWidth != null)
                SizedBox(width: leftWidth, child: col(left))
              else
                Expanded(flex: leftFlex, child: col(left)),
              SizedBox(width: gap),
              Expanded(flex: rightFlex, child: col(right)),
            ],
          ),
        ],
      );
    });
  }
}
