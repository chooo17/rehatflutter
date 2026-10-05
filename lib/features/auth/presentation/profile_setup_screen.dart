import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

/// Onboarding: melengkapi profil (nama wajib, tanggal lahir opsional)
/// setelah verifikasi OTP berhasil.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  DateTime? _birthdate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final birthdateStr = _birthdate == null
        ? null
        : '${_birthdate!.year.toString().padLeft(4, '0')}-'
            '${_birthdate!.month.toString().padLeft(2, '0')}-'
            '${_birthdate!.day.toString().padLeft(2, '0')}';

    final ok = await ref.read(authControllerProvider.notifier).completeProfile(
          name: _nameCtrl.text.trim(),
          birthdate: birthdateStr,
        );

    if (!mounted) return;
    if (!ok) {
      final msg = ref.read(authControllerProvider).errorMessage ??
          'Gagal menyimpan profil.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
    // Sukses: profil lengkap → redirect router otomatis ke beranda.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
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
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.amber, size: 30),
                ),
                const SizedBox(height: 28),
                Text('Lengkapi profil', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Satu langkah lagi. Beri tahu kami namamu agar pengalaman lebih personal.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  label: 'Nama lengkap',
                  controller: _nameCtrl,
                  hintText: 'Nama kamu',
                  prefixIcon: Icons.badge_outlined,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Nama wajib diisi';
                    if (value.length < 2) return 'Nama terlalu pendek';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Text('Tanggal lahir (opsional)', style: AppTextStyles.label),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickBirthdate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake_outlined,
                            color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _birthdate == null
                              ? 'Pilih tanggal lahir'
                              : Formatters.tanggal(_birthdate!),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: _birthdate == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Selesai',
                  isLoading: state.isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Kamu bisa melengkapi data lain nanti di Profil.',
                    style: AppTextStyles.bodySmall,
                  ),
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
