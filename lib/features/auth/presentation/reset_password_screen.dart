import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/otp_boxes.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_split_layout.dart';

/// Layar reset password: masukkan kode OTP + kata sandi baru.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.otpToken,
    required this.phone,
    this.otpSent = true,
  });

  final String otpToken;
  final String phone;
  final bool otpSent;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final code = _codeCtrl.text.trim();
    if (code.length != _codeLength) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Masukkan 6 digit kode OTP.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authControllerProvider.notifier).resetPassword(
          otpToken: _otpToken,
          otpCode: code,
          newPassword: _passwordCtrl.text,
        );

    if (!mounted) return;
    if (ok) {
      context.goNamed(RouteNames.login);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Kata sandi berhasil diperbarui. Silakan masuk.')));
    } else {
      _codeCtrl.clear();
      final msg = ref.read(authControllerProvider).errorMessage ??
          'Gagal reset kata sandi. Coba lagi.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
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
              : context.goNamed(RouteNames.login),
        ),
      ),
      body: SafeArea(
        child: AuthSplitLayout(child: ResponsiveCenter(
          maxWidth: 480,
          centerVertically: true,
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset kata sandi', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    children: [
                      const TextSpan(
                          text: 'Masukkan 6 digit kode yang dikirim ke '),
                      TextSpan(
                        text: widget.phone,
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.espresso),
                      ),
                      const TextSpan(text: ' lalu buat kata sandi baru.'),
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
                const SizedBox(height: 28),
                OtpBoxes(
                  controller: _codeCtrl,
                  focusNode: _codeFocus,
                  length: _codeLength,
                  onCompleted: (_) => _codeFocus.unfocus(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Kata sandi baru',
                  controller: _passwordCtrl,
                  hintText: 'Minimal 8 karakter',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (value.isEmpty) return 'Kata sandi wajib diisi';
                    if (value.length < 8) return 'Minimal 8 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Ulangi kata sandi baru',
                  controller: _confirmCtrl,
                  hintText: 'Ketik ulang kata sandi',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) {
                    if ((v ?? '') != _passwordCtrl.text) {
                      return 'Kata sandi tidak sama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Simpan kata sandi baru',
                  isLoading: state.isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
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
        )),
      ),
    );
  }
}
