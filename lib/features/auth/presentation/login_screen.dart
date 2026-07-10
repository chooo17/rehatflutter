import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

/// Layar masuk (login) menggunakan nomor telepon & kata sandi.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authControllerProvider.notifier).login(
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (!ok && mounted) {
      final msg = ref.read(authControllerProvider).errorMessage ??
          'Gagal masuk. Coba lagi.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
    // Navigasi ditangani otomatis oleh redirect router setelah login sukses.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.coffee_rounded,
                      color: AppColors.amber, size: 30),
                ),
                const SizedBox(height: 28),
                Text('Selamat datang kembali', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Masuk untuk memesan kopi favoritmu dan kumpulkan poin.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  label: 'Nomor telepon',
                  controller: _phoneCtrl,
                  hintText: '08xxxxxxxxxx',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Kata sandi',
                  controller: _passwordCtrl,
                  hintText: 'Masukkan kata sandi',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
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
                    if ((v ?? '').isEmpty) return 'Kata sandi wajib diisi';
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                            content: Text(
                                'Reset kata sandi belum tersedia. Hubungi admin di halo@rehat.coffee')));
                    },
                    child: const Text('Lupa kata sandi?'),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Masuk',
                  isLoading: state.isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 14),
                // Lanjut tanpa login — hanya bisa melihat menu.
                NeuButton(
                  expand: true,
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).continueAsGuest();
                    context.goNamed(RouteNames.guestMenu);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_rounded,
                          size: 18, color: AppColors.espresso),
                      const SizedBox(width: 8),
                      Text('Lihat Menu Tanpa Login',
                          style: AppTextStyles.button
                              .copyWith(color: AppColors.espresso)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun? ',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.goNamed(RouteNames.register),
                      child: Text(
                        'Daftar',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.amberDark),
                      ),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 350.ms).slideY(
                  begin: 0.04,
                  end: 0,
                  duration: 350.ms,
                  curve: Curves.easeOut,
                ),
          ),
        ),
      ),
    );
  }
}
