import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Gambar jaringan yang aman di web. Di web CanvasKit, gambar lintas-domain
/// tanpa header CORS gagal dimuat lewat fetch — jadi di web dipakai elemen HTML
/// `<img>` (bypass batasan itu). Di mobile memakai CachedNetworkImage (cache).
class WebSafeImage extends StatelessWidget {
  const WebSafeImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
  });

  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) => error ?? const SizedBox.shrink(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : (placeholder ?? child),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => placeholder ?? const SizedBox.shrink(),
      errorWidget: (_, __, ___) => error ?? const SizedBox.shrink(),
    );
  }
}
