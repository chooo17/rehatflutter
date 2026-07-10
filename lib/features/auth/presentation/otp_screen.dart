import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

/// Layar verifikasi OTP 6 digit setelah register.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.otpToken, required this.phone});

  final String otpToken;
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeCtrl = TextEditingController();
  final _focus = FocusNode();
  late String _otpToken;
  Timer? _timer;
  int _secondsLeft = 60;

  static const int _codeLength = 6;

  @override
  void initState() {
    super.initState();
    _otpToken = widget.otpToken;
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
    final newToken =
        await ref.read(authControllerProvider.notifier).resendOtp(_otpToken);
    if (!mounted) return;
    if (newToken != null) {
      _otpToken = newToken;
      _codeCtrl.clear();
      _startCountdown();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Kode OTP baru telah dikirim.')));
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
              const SizedBox(height: 32),
              _OtpBoxes(
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
    );
  }
}

/// Enam kotak digit dengan satu [TextField] tersembunyi sebagai input.
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onCompleted,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    return Stack(
      children: [
        // Input tak terlihat namun menangkap ketikan & keyboard.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: length,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(length),
            ],
            onChanged: (v) {
              onChanged(v);
              if (v.length == length) onCompleted(v);
            },
          ),
        ),
        GestureDetector(
          onTap: () => focusNode.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(length, (i) {
              final filled = i < code.length;
              final isActive = i == code.length;
              return Container(
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppColors.amber
                        : filled
                            ? AppColors.espresso
                            : AppColors.border,
                    width: isActive ? 1.8 : 1,
                  ),
                ),
                child: Text(filled ? code[i] : '',
                    style: AppTextStyles.displaySmall),
              );
            }),
          ),
        ),
      ],
    );
  }
}
