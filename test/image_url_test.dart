import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/utils/image_url.dart';

void main() {
  const base = 'https://abc.supabase.co/storage/v1';

  group('resizedImageUrl', () {
    test('gambar publik Supabase -> endpoint render, WebP, lebar diminta', () {
      final out = resizedImageUrl('$base/object/public/menu/a1/123.png', 400);
      final uri = Uri.parse(out);
      expect(uri.path, '/storage/v1/render/image/public/menu/a1/123.png');
      expect(uri.queryParameters, {
        'width': '400',
        'resize': 'contain', // jaga rasio; tanpa ini tinggi asli dipertahankan
        'quality': '75',
        'format': 'webp',
      });
    });

    test('query lama dipertahankan', () {
      final out = resizedImageUrl('$base/object/public/menu/x.jpg?v=2', 300);
      final q = Uri.parse(out).queryParameters;
      expect(q['v'], '2');
      expect(q['width'], '300');
    });

    test('lebar dibulatkan ke kelipatan 100 (cache CDN lebih sering kena)', () {
      expect(Uri.parse(resizedImageUrl('$base/object/public/m/a.png', 333))
          .queryParameters['width'], '400');
      expect(Uri.parse(resizedImageUrl('$base/object/public/m/a.png', 400))
          .queryParameters['width'], '400');
    });

    test('URL non-Supabase tidak diubah', () {
      const url = 'https://cdn.example.com/storage/v1/object/public/a.png';
      expect(resizedImageUrl(url, 400), url);
    });

    test('Supabase tapi bukan objek publik (signed/privat) tidak diubah', () {
      const url = '$base/object/sign/menu/a.png?token=abc';
      expect(resizedImageUrl(url, 400), url);
    });

    test('sudah lewat render tidak diproses ulang', () {
      const url = '$base/render/image/public/menu/a.png?width=200';
      expect(resizedImageUrl(url, 400), url);
    });

    test('URL rusak/kosong dikembalikan apa adanya', () {
      expect(resizedImageUrl('', 400), '');
      expect(resizedImageUrl('bukan url', 400), 'bukan url');
    });
  });
}
