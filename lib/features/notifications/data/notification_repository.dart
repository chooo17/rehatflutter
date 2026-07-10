import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/notification_model.dart';

/// Akses data notifikasi.
class NotificationRepository {
  NotificationRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  Future<List<NotificationModel>> fetchAll() async {
    final res = await _client.get<dynamic>(ApiConstants.notifications);
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['notifications']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<void> markRead(String id) async {
    await _client.patch<dynamic>(ApiConstants.notificationRead(id));
  }

  Future<void> markAllRead() async {
    await _client.patch<dynamic>(ApiConstants.notificationsReadAll);
  }

  /// Mendaftarkan token FCM perangkat ke backend (untuk push notification).
  Future<void> registerDevice(String fcmToken) async {
    await _client.post<dynamic>(
      ApiConstants.registerDevice,
      data: {'fcm_token': fcmToken},
    );
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(client: ref.watch(dioClientProvider));
});

final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) {
  return ref.watch(notificationRepositoryProvider).fetchAll();
});

/// Jumlah notifikasi belum dibaca (untuk badge).
///
/// Memakai `valueOrNull` agar nilai lama tetap tampil saat penyegaran berkala
/// (poller), sehingga badge tidak berkedip ke 0 setiap refresh.
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});
