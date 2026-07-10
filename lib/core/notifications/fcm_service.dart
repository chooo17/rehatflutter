import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/data/notification_repository.dart';

/// Handler pesan saat app di background/terminated. Harus top-level & diberi
/// anotasi entry-point. Untuk payload `notification`, sistem menampilkannya
/// otomatis; di sini cukup tidak melakukan apa-apa (log saja).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notifikasi ditampilkan otomatis oleh OS. Tidak perlu aksi tambahan.
  debugPrint('[fcm] background message: ${message.messageId}');
}

/// Menginisialisasi Firebase & mendaftarkan background handler.
/// Aman gagal: bila konfigurasi belum lengkap, app tetap berjalan tanpa push.
Future<bool> initFirebaseMessaging() async {
  // Web (mode WebView/browser) tidak memakai FCM native — lewati agar tidak
  // memicu error init. Notifikasi in-app tetap jalan lewat polling.
  if (kIsWeb) return false;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return true;
  } catch (e) {
    debugPrint('[fcm] Firebase init dilewati: $e');
    return false;
  }
}

/// Layanan FCM sisi klien: minta izin, ambil & daftarkan token, pasang listener.
/// Dipanggil setelah pengguna terautentikasi (agar endpoint register punya JWT).
class FcmService {
  FcmService(this._ref);
  final Ref _ref;

  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _register(token);

      // Token bisa berganti; daftarkan ulang.
      messaging.onTokenRefresh.listen((t) => _register(t));

      // Push saat app di foreground → segarkan daftar/badge notifikasi.
      FirebaseMessaging.onMessage.listen((_) {
        _ref.invalidate(notificationsProvider);
      });
    } catch (e) {
      debugPrint('[fcm] start dilewati: $e');
      _started = false; // biar bisa dicoba lagi nanti
    }
  }

  Future<void> _register(String token) async {
    try {
      await _ref.read(notificationRepositoryProvider).registerDevice(token);
    } catch (e) {
      debugPrint('[fcm] gagal daftar token: $e');
    }
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));
