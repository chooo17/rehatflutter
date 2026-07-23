import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Apakah aplikasi sedang berada di DEPAN (foreground).
///
/// Dipakai oleh polling berkala (mis. `ordersTrackingProvider`) agar berhenti
/// menembak backend saat aplikasi di background — hemat kuota & baterai.
/// Di-update oleh [AppLifecycleWatcher] yang dipasang sekali di root aplikasi.
final appForegroundProvider = StateProvider<bool>((ref) => true);

/// Pemantau siklus hidup aplikasi. Pasang SEKALI di root (bungkus `MaterialApp`)
/// agar seluruh polling punya satu sumber kebenaran soal foreground/background.
class AppLifecycleWatcher extends ConsumerStatefulWidget {
  const AppLifecycleWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleWatcher> createState() =>
      _AppLifecycleWatcherState();
}

class _AppLifecycleWatcherState extends ConsumerState<AppLifecycleWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (ref.read(appForegroundProvider) != isForeground) {
      ref.read(appForegroundProvider.notifier).state = isForeground;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
