import 'package:flutter/material.dart';

import 'auth_brand.dart';

/// Tata letak layar auth (dipakai keenam layar: Login, Daftar, OTP, Lupa/
/// Reset sandi, Lengkapi profil).
///
/// Layar lebar (>= 900): split-screen — [AuthBrandPanel] di kiri, form di
/// kanan. Layar sempit: [AuthBrandHeader] di atas form (header menyembunyikan
/// dirinya saat keyboard terbuka / layar pendek).
class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader(),
            Expanded(child: child),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: AuthBrandPanel()),
          Expanded(child: child),
        ],
      );
    });
  }
}
