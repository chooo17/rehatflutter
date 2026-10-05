import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/otp_boxes.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

/// Layar verifikasi OTP 6 digit setelah register.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen(
      {super.key,
      required this.otpToken,
      required this.phone,
      this.otpSent = true});

  final String otpToken;
  final String phone;

  /// `false` bila server gagal mengirim OTP otomatis — tampilkan peringatan.
  final bool otpSent;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeCtrl = TextEditingController();
  final _focus = FocusNode();
  late String _otpToken;
  late bool _otpSent;
  Timer? _timer;
  int _secondsLeft = 60;

  static const int _codeLength = 6;

  @override
  void initState() {
    super.initState();
    _otpToken = widget.otpToken;
    _otpSent = widget.otpSent;
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _secondsLeft = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final code = _codeCtrl.text.trim();
    if (code.length != _codeLength) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Masukkan 6 digit kode OTP.')));
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(otpToken: _otpToken, otpCode: code);

    if (!mounted) return;
    if (!ok) {
      _codeCtrl.clear();
      final msg = ref.read(authControllerProvider).errorMessage ??
          'Verifikasi gagal. Coba lagi.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
    // Sukses: redirect router otomatis mengarahkan ke profile setup / home.
  }

  Future<void> _resend() async {
    final result =
        await ref.read(authControllerProvider.notifier).resendOtp(_otpToken);
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _otpToken = result.otpToken;
        _otpSent = result.otpSent;
      });
      _codeCtrl.clear();
      _startCountdown();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(result.otpSent
                ? 'Kode OTP baru telah dikirim.'
                : 'OTP masih gagal terkirim. Coba lagi sebentar atau hubungi admin.')));
    } else {
      final msg = ref.read(authControllerProvider).errorMessage ??
          'Gagal mengirim ulang OTP.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.register),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verifikasi OTP', style: AppTextStyles.displayMedium),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  children: [
                    const TextSpan(text: 'Masukkan 6 digit kode yang dikirim ke '),
                    TextSpan(
                      text: widget.phone,
                      style: AppTextStyles.label.copyWith(color: AppColors.espresso),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              if (!_otpSent) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kode OTP gagal terkirim otomatis. Tekan "Kirim ulang '
                          'kode OTP" di bawah, atau hubungi admin bila tetap tak masuk.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              OtpBoxes(
                controller: _codeCtrl,
                focusNode: _focus,
                length: _codeLength,
                onCompleted: (_) => _verify(),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Verifikasi',
                isLoading: state.isSubmitting,
                onPressed: _verify,
              ),
              const SizedBox(height: 20),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Kirim ulang kode dalam ${_secondsLeft}s',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Kirim ulang kode OTP'),
                      ),
              ),
            ],
          ).animate().fadeIn(duration: 350.ms),
        ),
        ),
      ),
    );
  }
}
