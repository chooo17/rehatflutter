import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/analytics/analytics_service.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_theme.dart';
import 'core/notifications/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/app_lifecycle.dart';
import 'shared/widgets/neu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi data locale untuk format tanggal & mata uang (id_ID).
  await initializeDateFormatting('id_ID');
  // Inisialisasi Firebase Messaging (aman gagal bila konfigurasi belum lengkap).
  final firebaseReady = await initFirebaseMessaging();
  // Aktifkan analitik funnel hanya bila Firebase siap (mobile). Di web/atau bila
  // init gagal, semua panggilan Analytics jadi no-op (aman).
  if (firebaseReady) Analytics.enable();
  // Pemantau crash (mobile saja; web tidak didukung Crashlytics). Semua error
  // Flutter & async fatal diteruskan ke Firebase Console dengan stack trace.
  if (firebaseReady) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  runApp(const ProviderScope(child: RehatApp()));
}

class RehatApp extends ConsumerStatefulWidget {
  const RehatApp({super.key});

  @override
  ConsumerState<RehatApp> createState() => _RehatAppState();
}

class _RehatAppState extends ConsumerState<RehatApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Tirai transisi tema: menutup layar dengan warna latar LAMA lalu memudar,
  // sehingga pergantian terang↔gelap tampak halus (bukan potong keras).
  late final AnimationController _fade;
  Brightness? _lastBrightness;
  Color _curtainColor = AppColors.backgroundFor(Brightness.light);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Bila mengikuti tema sistem, bangun ulang saat OS berganti terang/gelap.
    if (ref.read(themeModeControllerProvider) == ThemeMode.system) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeControllerProvider);

    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => systemBrightness,
    };

    // Set brightness global sinkron sebelum subtree dibangun.
    AppColors.brightness = brightness;

    // Saat brightness berganti: pasang tirai warna lama (opasitas penuh) lalu
    // pudarkan pasca-frame agar warna baru tersingkap mulus.
    if (_lastBrightness != null && _lastBrightness != brightness) {
      _curtainColor = AppColors.backgroundFor(_lastBrightness!);
      _fade.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fade.animateTo(0, curve: Curves.easeOut);
      });
    }
    _lastBrightness = brightness;

    return AppLifecycleWatcher(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
          Positioned.fill(
            child: MaterialApp.router(
              // Key mengikuti brightness → paksa rebuild penuh agar SEMUA warna
              // (termasuk layar const & widget non-Theme) ikut berganti.
              key: ValueKey(brightness),
              title: 'Rehat',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(brightness),
              builder: (context, child) => NeuThemeScope(
                mode: mode,
                child: child ?? const SizedBox.shrink(),
              ),
              routerConfig: router,
              locale: const Locale('id', 'ID'),
              supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _fade,
                builder: (context, _) {
                  final opacity = _fade.value.clamp(0.0, 1.0);
                  if (opacity <= 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: opacity,
                    child: ColoredBox(color: _curtainColor),
                  );
                },
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
