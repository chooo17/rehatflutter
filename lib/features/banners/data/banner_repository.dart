import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/banner_model.dart';

/// Akses data banner promo.
class BannerRepository {
  BannerRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  List<BannerModel> _parse(dynamic data) {
    final list = data is Map ? (data['data'] ?? data['banners']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => BannerModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Banner aktif untuk beranda.
  Future<List<BannerModel>> fetchActive() async {
    final res = await _client.get<dynamic>(ApiConstants.banners);
    return _parse(res.data);
  }

  /// (Admin) Semua banner untuk pengelolaan.
  Future<List<BannerModel>> fetchAll() async {
    final res = await _client.get<dynamic>(ApiConstants.adminBanners);
    return _parse(res.data);
  }

  Future<void> create(Map<String, dynamic> body) async {
    await _client.post<dynamic>(ApiConstants.banners, data: body);
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _client.patch<dynamic>(ApiConstants.banner(id), data: body);
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>(ApiConstants.banner(id));
  }

  /// (Admin) Upload gambar banner dari perangkat → mengembalikan URL publik.
  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _client.post<dynamic>(
      ApiConstants.adminBannerUpload,
      data: form,
    );
    final data = res.data;
    final inner = data is Map ? (data['data'] ?? data) : const {};
    final url = (inner is Map ? inner['image_url'] : null)?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('URL gambar tidak ditemukan pada respons.');
    }
    return url;
  }
}

final bannerRepositoryProvider = Provider<BannerRepository>((ref) {
  return BannerRepository(client: ref.watch(dioClientProvider));
});

/// Banner aktif untuk beranda. Aman gagal: bila error/kosong → daftar kosong
/// (carousel disembunyikan), jadi beranda tak rusak sebelum migrasi/isian.
final activeBannersProvider = FutureProvider<List<BannerModel>>((ref) async {
  try {
    return await ref.watch(bannerRepositoryProvider).fetchActive();
  } catch (_) {
    return const [];
  }
});

/// (Admin) Semua banner.
final adminBannersProvider = FutureProvider<List<BannerModel>>((ref) {
  return ref.watch(bannerRepositoryProvider).fetchAll();
});
