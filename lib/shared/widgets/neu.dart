import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

/// Fondasi desain neumorphic Rehat: tema (terang/gelap) + komponen reusable.
///
/// Neumorphism = permukaan satu warna dengan bayangan terang (kiri-atas) &
/// gelap (kanan-bawah) untuk kesan timbul/tenggelam. Warna dasar = latar app.

const _kAccent = Color(0xFFB47832); // amber
const _kInkLight = Color(0xFF0F0907); // espresso
const _kInkDark = Color(0xFFEDE6D6); // crema terang

NeumorphicThemeData neuLightTheme() => const NeumorphicThemeData(
      baseColor: Color(0xFFE9E3D5),
      accentColor: _kAccent,
      variantColor: Color(0xFF8F5E26),
      // Kontras bayangan diperkuat (terang lebih terang, gelap lebih gelap)
      // untuk kesan timbul-tenggelam yang lebih dalam.
      shadowLightColor: Color(0xFFFFFDF6),
      shadowDarkColor: Color(0xFFB2A78C),
      shadowLightColorEmboss: Color(0xFFFFFDF6),
      shadowDarkColorEmboss: Color(0xFFB2A78C),
      defaultTextColor: _kInkLight,
      // Depth diturunkan (blur shadow lebih kecil) → render jauh lebih ringan
      // saat pindah halaman/scroll, tampilan tetap timbul.
      depth: 6,
      intensity: 0.8,
      lightSource: LightSource.topLeft,
    );

NeumorphicThemeData neuDarkTheme() => const NeumorphicThemeData(
      baseColor: Color(0xFF23201A),
      accentColor: _kAccent,
      variantColor: Color(0xFFD9A766),
      shadowLightColor: Color(0xFF3C362C),
      shadowDarkColor: Color(0xFF0A0805),
      shadowLightColorEmboss: Color(0xFF3C362C),
      shadowDarkColorEmboss: Color(0xFF0A0805),
      defaultTextColor: _kInkDark,
      depth: 5,
      intensity: 0.75,
      lightSource: LightSource.topLeft,
    );

/// Menyediakan [NeumorphicTheme] (terang/gelap) untuk seluruh anak.
/// Dipasang di `MaterialApp.builder` agar semua rute punya tema neumorphic.
class NeuThemeScope extends StatelessWidget {
  const NeuThemeScope({super.key, required this.child, required this.mode});

  final Widget child;
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    return NeumorphicTheme(
      theme: neuLightTheme(),
      darkTheme: neuDarkTheme(),
      themeMode: mode,
      child: child,
    );
  }
}

/// Kartu neumorphic timbul (raised).
class NeuCard extends StatelessWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.depth = 5,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double depth;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = NeumorphicStyle(
      depth: depth,
      intensity: 0.82,
      color: color,
      boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(radius)),
    );
    // RepaintBoundary: cache raster kartu neumorphic (shadow mahal) agar saat
    // scroll cukup di-translate, tidak di-repaint tiap frame.
    return RepaintBoundary(
      child: onTap != null
          ? NeumorphicButton(
              onPressed: onTap,
              style: style,
              padding: padding,
              child: child,
            )
          : Neumorphic(style: style, padding: padding, child: child),
    );
  }
}

/// Permukaan tenggelam (inset/emboss) — untuk field, "sumur", segmen aktif.
class NeuInset extends StatelessWidget {
  const NeuInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.depth = 5,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double depth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -depth,
        intensity: 0.9,
        color: color,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(radius)),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Tombol neumorphic. [accent] = terisi amber (aksi utama).
class NeuButton extends StatelessWidget {
  const NeuButton({
    super.key,
    required this.child,
    this.onPressed,
    this.accent = false,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.expand = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool accent;
  final double radius;
  final EdgeInsets padding;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = NeumorphicButton(
      onPressed: onPressed,
      padding: padding,
      style: NeumorphicStyle(
        depth: accent ? 4 : 5,
        intensity: 0.82,
        color: accent ? _kAccent : null,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(radius)),
      ),
      // heightFactor 1.0 → tombol selalu membungkus tinggi isinya. Tanpa ini,
      // di dalam tinggi bounded (mis. bottomNavigationBar) Center akan memuai
      // memenuhi tinggi layar. widthFactor dilepas saat [expand] agar mengisi
      // lebar penuh untuk penengahan horizontal.
      child: Align(
        alignment: Alignment.center,
        heightFactor: 1,
        widthFactor: expand ? null : 1,
        child: child,
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Bar bawah neumorphic timbul (sudut atas membulat) — untuk checkout/aksi.
class NeuBottomBar extends StatelessWidget {
  const NeuBottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Neumorphic(
      style: NeumorphicStyle(
        depth: 8,
        intensity: 0.82,
        boxShape: NeumorphicBoxShape.roundRect(
          const BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: child,
    );
  }
}

/// Tombol ikon bundar neumorphic.
class NeuCircleButton extends StatelessWidget {
  const NeuCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 46,
    this.iconColor,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: NeumorphicButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: const NeumorphicStyle(
          depth: 5,
          intensity: 0.82,
          boxShape: NeumorphicBoxShape.circle(),
        ),
        child: Icon(icon,
            size: iconSize,
            color: iconColor ?? NeumorphicTheme.defaultTextColor(context)),
      ),
    );
  }
}
