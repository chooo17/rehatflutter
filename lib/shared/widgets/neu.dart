import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Komponen permukaan Rehat — kini **flat** (border tipis, tanpa neumorphic).
///
/// API dipertahankan sama seperti versi neumorphic lama agar 30+ pemanggil
/// tak perlu diubah. Gaya flat = jauh lebih ringan saat scroll/pindah halaman
/// dan menghapus dependency `flutter_neumorphic_plus`.

/// Dulu menyediakan NeumorphicTheme; kini sekadar passthrough (tema warna
/// ditangani oleh [AppColors] + ThemeData). [mode] dipertahankan untuk kompat.
class NeuThemeScope extends StatelessWidget {
  const NeuThemeScope({super.key, required this.child, required this.mode});

  final Widget child;
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) => child;
}

/// Kartu permukaan (dulu "timbul") — kini flat dengan border tipis.
class NeuCard extends StatelessWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.depth = 5, // diabaikan (kompat)
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
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
    return RepaintBoundary(child: content);
  }
}

/// Permukaan tenggelam (field/"sumur"/segmen aktif) — flat dengan bg crema.
class NeuInset extends StatelessWidget {
  const NeuInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.depth = 5, // diabaikan (kompat)
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double depth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.crema,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Tombol. [accent] = terisi amber (aksi utama), selain itu permukaan + border.
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
    final disabled = onPressed == null;
    final bg = accent
        ? (disabled ? AppColors.amber.withValues(alpha: 0.4) : AppColors.amber)
        : AppColors.surface;
    final btn = Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      shape: accent
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: AppColors.border),
            ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding,
          // heightFactor 1 → tombol membungkus tinggi isinya (lihat catatan
          // NeuButton height); widthFactor dilepas saat [expand].
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            widthFactor: expand ? null : 1,
            child: child,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Bar bawah (sudut atas membulat) — untuk checkout/aksi. Flat + garis atas.
class NeuBottomBar extends StatelessWidget {
  const NeuBottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }
}

/// Tombol ikon bundar — flat dengan border tipis.
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
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon,
              size: iconSize, color: iconColor ?? AppColors.textPrimary),
        ),
      ),
    );
  }
}
