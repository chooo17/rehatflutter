import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Membuat aplikasi mobile-first tampil rapi di semua ukuran layar.
///
/// - **Mobile** (≤ [maxWidth]): konten memenuhi lebar layar seperti biasa.
/// - **Tablet / desktop**: konten dibatasi selebar [maxWidth] dan dipusatkan,
///   dengan latar halaman di kiri-kanannya — agar tak melar & tetap terbaca.
///
/// Dipasang di `MaterialApp.builder` sehingga semua rute, bottom sheet, dialog,
/// dan snackbar ikut terpusat. MediaQuery di dalam juga di-override ke [maxWidth]
/// agar widget yang menghitung dari lebar layar tetap konsisten.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.child, this.maxWidth = 900});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth) return child;

    final dark = AppColors.brightness == Brightness.dark;
    final backdrop = dark ? const Color(0xFF15120D) : const Color(0xFFD9D1C0);

    return ColoredBox(
      color: backdrop,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
