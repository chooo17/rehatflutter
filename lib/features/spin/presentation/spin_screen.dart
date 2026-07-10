import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/spin_model.dart';
import '../data/spin_repository.dart';
import 'widgets/spin_wheel.dart';

/// Permainan Spin the Wheel: putar roda, menangkan hadiah.
class SpinScreen extends ConsumerStatefulWidget {
  const SpinScreen({super.key});

  @override
  ConsumerState<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends ConsumerState<SpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Animation<double> _anim = const AlwaysStoppedAnimation(0);
  double _rotation = 0;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _rotation = _anim.value;
      setState(() => _spinning = false);
      _showResult(_pendingResult!);
    }
  }

  SpinResult? _pendingResult;

  Future<void> _spin(List<SpinPrize> prizes) async {
    if (_spinning || prizes.isEmpty) return;
    setState(() => _spinning = true);

    final SpinResult result;
    try {
      result = await ref.read(spinRepositoryProvider).spin();
    } catch (e) {
      if (!mounted) return;
      setState(() => _spinning = false);
      // Sudah pakai spin gratis hari ini → popup ramah, bukan error mentah.
      final alreadySpun = e is ApiException &&
          (e.code == 'SPIN_ALREADY_USED_TODAY' || e.statusCode == 409);
      if (alreadySpun) {
        _showInfoDialog(
          title: 'Spin gratis harian sudah habis',
          message: 'Kamu sudah memakai putaran gratis hari ini.\nCoba lagi besok, ya! 🎡',
          icon: Icons.hourglass_bottom_rounded,
        );
      } else {
        _showInfoDialog(
          title: 'Gagal memutar',
          message: e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.',
          icon: Icons.error_outline_rounded,
        );
      }
      // Segarkan status agar tombol nonaktif bila kuota habis.
      ref.invalidate(spinStatusProvider);
      return;
    }
    _pendingResult = result;

    final n = prizes.length;
    final seg = 2 * pi / n;
    // Rotasi agar segmen pemenang berhenti tepat di penunjuk atas.
    final desiredMod = (-result.prizeIndex * seg) % (2 * pi);
    final currentMod = _rotation % (2 * pi);
    var forward = (desiredMod - currentMod) % (2 * pi);
    if (forward < 0) forward += 2 * pi;
    const extraTurns = 5;
    final target = _rotation + extraTurns * 2 * pi + forward;

    _anim = Tween<double>(begin: _rotation, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    )..addListener(() => setState(() {}));
    _ctrl
      ..reset()
      ..forward();
  }

  void _showInfoDialog({
    required String title,
    required String message,
    required IconData icon,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, color: AppColors.amberDark, size: 40),
        title: Text(title,
            textAlign: TextAlign.center, style: AppTextStyles.titleLarge),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti'),
            ),
          ),
        ],
      ),
    );
  }

  void _showResult(SpinResult result) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _ResultSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(spinStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.espresso,
      appBar: AppBar(
        backgroundColor: AppColors.espresso,
        foregroundColor: AppColors.crema,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Putar & Menang',
            style: AppTextStyles.headline.copyWith(color: AppColors.crema)),
      ),
      body: statusAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amberLight)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(spinStatusProvider),
        ),
        data: (status) => _content(status),
      ),
    );
  }

  Widget _content(SpinStatus status) {
    final canSpin = status.canSpin && !_spinning;
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Putar roda dan menangkan kopi gratis, voucher, atau poin bonus!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.crema.withValues(alpha: 0.8)),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SpinWheel(
                        prizes: status.prizes,
                        rotation: _anim.value,
                      ),
                    ),
                    const WheelPointer(),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSpin ? () => _spin(status.prizes) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.espresso,
                  disabledBackgroundColor:
                      AppColors.amber.withValues(alpha: 0.4),
                ),
                child: Text(
                  _spinning
                      ? 'Memutar…'
                      : status.canSpin
                          ? 'PUTAR SEKARANG'
                          : 'Coba lagi besok',
                  style: AppTextStyles.button.copyWith(
                      color: AppColors.espresso, letterSpacing: 1),
                ),
              ),
            ),
          ),
          Text(
            'Gratis 1x putaran setiap hari',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.crema.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.result});
  final SpinResult result;

  @override
  Widget build(BuildContext context) {
    final win = result.isWin;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: win ? AppColors.amber : AppColors.crema,
              shape: BoxShape.circle,
            ),
            child: Icon(
              win ? Icons.celebration_rounded : Icons.sentiment_neutral_rounded,
              color: win ? AppColors.espresso : AppColors.amberDark,
              size: 44,
            ),
          )
              .animate()
              .scale(duration: 400.ms, curve: Curves.easeOutBack)
              .fadeIn(),
          const SizedBox(height: 20),
          Text(win ? 'Selamat! 🎉' : 'Yah, belum beruntung',
              style: AppTextStyles.displaySmall),
          const SizedBox(height: 8),
          Text(
            result.message ??
                (win
                    ? 'Kamu memenangkan ${result.prize.label.replaceAll('\n', ' ')}.'
                    : 'Coba lagi besok, ya. Tetap semangat!'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(win ? 'Klaim Hadiah' : 'Tutup'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppColors.crema.withValues(alpha: 0.7), size: 36),
          const SizedBox(height: 10),
          Text('Gagal memuat permainan.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.crema)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text('Coba lagi',
                style: AppTextStyles.label.copyWith(color: AppColors.amberLight)),
          ),
        ],
      ),
    );
  }
}
