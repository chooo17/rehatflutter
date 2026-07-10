import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';

/// Mengubah profil pengguna (nama + tanggal lahir).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  DateTime? _birthdate;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _birthdate = user?.birthdate != null ? DateTime.tryParse(user!.birthdate!) : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    final bytes = await picked.readAsBytes();
    final ok = await ref.read(authControllerProvider.notifier).uploadAvatar(
          bytes: bytes,
          filename: picked.name,
        );
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok
            ? 'Foto profil diperbarui'
            : (ref.read(authControllerProvider).errorMessage ??
                'Gagal mengunggah foto')),
      ));
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _save() async {
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
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      context.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profil diperbarui')));
    } else {
      final msg = ref.read(authControllerProvider).errorMessage ??
          'Gagal menyimpan profil.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final user = state.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        NeuCard(
                          padding: EdgeInsets.zero,
                          radius: 28,
                          child: SizedBox(
                          width: 96,
                          height: 96,
                          child: _uploadingAvatar
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: AppColors.amber),
                                  ),
                                )
                              : (user?.avatarUrl != null &&
                                      user!.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: user.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Icon(
                                          Icons.person_rounded,
                                          color: AppColors.amberDark,
                                          size: 48),
                                    )
                                  : Icon(Icons.person_rounded,
                                      color: AppColors.amberDark, size: 48)),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.espresso,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.backgroundLight, width: 2),
                            ),
                            child: Icon(Icons.camera_alt_rounded,
                                color: AppColors.crema, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Nama lengkap',
                  controller: _nameCtrl,
                  hintText: 'Nama kamu',
                  prefixIcon: Icons.badge_outlined,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Nama wajib diisi';
                    if (value.length < 2) return 'Nama terlalu pendek';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                // Nomor HP (read-only — identifier akun).
                Text('Nomor telepon', style: AppTextStyles.label),
                const SizedBox(height: 8),
                NeuInset(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  radius: 14,
                  child: Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(user?.phone ?? '-',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.textSecondary)),
                      const Spacer(),
                      Icon(Icons.lock_outline_rounded,
                          color: AppColors.textSecondary, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Tanggal lahir', style: AppTextStyles.label),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickBirthdate,
                  child: NeuInset(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    radius: 14,
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
                  label: 'Simpan',
                  isLoading: state.isSubmitting,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
