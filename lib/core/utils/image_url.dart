/// Mengubah URL gambar publik Supabase Storage menjadi versi yang diperkecil
/// di server (Supabase Image Transformation), sehingga yang diunduh hanya
/// sebesar yang ditampilkan.
///
/// Latar belakang: foto menu diunggah apa adanya (PNG 1280px, s/d ~3,5 MB per
/// gambar, ±37 MB untuk seluruh katalog). `memCacheWidth`/`cacheWidth` hanya
/// mengecilkan SETELAH unduhan selesai, jadi tidak menghemat kuota/waktu muat.
/// Lewat endpoint render, satu kartu menu turun ke ~20 KB (WebP 400px).
///
/// - `resize=contain` WAJIB: dengan `width` saja Supabase mempertahankan tinggi
///   asli (hasilnya 400x1280, gepeng).
/// - `format=webp` dipaksa lewat query karena request gambar Flutter web tidak
///   mengirim `Accept: image/webp` (tanpa ini hasilnya PNG ~290 KB).
/// - Lebar dibulatkan ke atas kelipatan 100 agar variasi URL sedikit dan cache
///   CDN Supabase lebih sering kena.
///
/// URL selain objek publik Supabase (signed, CDN lain, aset lokal) dikembalikan
/// apa adanya.
String resizedImageUrl(String url, int width, {int quality = 75}) {
  const marker = '/storage/v1/object/public/';
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.host.endsWith('.supabase.co') ||
      !uri.path.contains(marker)) {
    return url;
  }
  final w = ((width + 99) ~/ 100) * 100;
  return uri.replace(
    path: uri.path.replaceFirst(marker, '/storage/v1/render/image/public/'),
    queryParameters: {
      ...uri.queryParameters,
      'width': '$w',
      'resize': 'contain',
      'quality': '$quality',
      'format': 'webp',
    },
  ).toString();
}
