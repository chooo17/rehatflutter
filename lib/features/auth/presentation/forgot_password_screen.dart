import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

/// Layar "Lupa kata sandi": masukkan no. HP → OTP reset dikirim via WhatsApp.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneCtrl.text.trim();
    final result = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(phone: phone);

    if (!mounted) return;
    if (result != null) {
      context.pushNamed(
        RouteNames.resetPassword,
        extra: {
          'otpToken': result.otpToken,
          'phone': phone,
          'otpSent': result.otpSent,
        },
      );
    } else {
      final msg = ref.read(authControllerProvider).errorMessage ??
          'Gagal memproses. Coba lagi.';
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
        child: ResponsiveCenter(
          maxWidth: 480,
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lupa kata sandi', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Masukkan nomor HP akunmu. Kami akan mengirim kode OTP untuk '
                  'mengatur ulang kata sandi.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Nomor telepon',
                  controller: _phoneCtrl,
                  hintText: '08xxxxxxxxxx',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  ],
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Nomor telepon wajib diisi';
                    if (value.length < 9) return 'Nomor telepon tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Kirim kode OTP',
                  isLoading: state.isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ).animate().fadeIn(duration: 350.ms),
          ),
        ),
        ),
      ),
    );
  }
}
