import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/fcm_service.dart';
import '../../data/notification_repository.dart';

/// Widget tak-terlihat yang menyegarkan notifikasi secara berkala selama app
/// aktif (foreground), sehingga badge lonceng ikut ter-update tanpa membuka
/// layar notifikasi. Berhenti saat app di-background, lanjut saat kembali.
class NotificationPoller extends ConsumerStatefulWidget {
  const NotificationPoller({super.key});

  @override
  ConsumerState<NotificationPoller> createState() => _NotificationPollerState();
}

class _NotificationPollerState extends ConsumerState<NotificationPoller>
    with WidgetsBindingObserver {
  Timer? _timer;
  static const _interval = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    // Daftarkan perangkat untuk push (setelah pengguna terautentikasi — shell
    // hanya tampil saat login). Aman gagal bila FCM belum dikonfigurasi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      ref.invalidate(notificationsProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationsProvider); // segera segarkan saat kembali
      _start();
    } else {
      _timer?.cancel(); // jeda saat background
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
