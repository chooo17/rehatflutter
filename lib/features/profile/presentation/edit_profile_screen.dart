import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
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

  /// Tanggal lahir dikunci bila sudah pernah diisi (anti-kecurangan voucher
  /// ulang tahun). Backend menegakkan aturan yang sama; ini hanya UX.
  bool _birthdateLocked = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _birthdate =
        user?.birthdate != null ? DateTime.tryParse(user!.birthdate!) : null;
    _birthdateLocked = (user?.birthdate ?? '').isNotEmpty;
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
    if (_birthdateLocked) return; // terkunci setelah terisi
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

    final avatar = GestureDetector(
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
                            strokeWidth: 2.4, color: AppColors.amber),
                      ),
                    )
                  : (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
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
                border: Border.all(color: AppColors.backgroundLight, width: 2),
              ),
              child: Icon(Icons.camera_alt_rounded,
                  color: AppColors.crema, size: 16),
            ),
          ),
        ],
      ),
    );
    final nameField = AppTextField(
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
    );
    final phoneField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nomor telepon', style: AppTextStyles.label),
        const SizedBox(height: 8),
        NeuInset(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      ],
    );
    final birthField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tanggal lahir', style: AppTextStyles.label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthdate,
          child: NeuInset(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                if (_birthdateLocked) ...[
                  const Spacer(),
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.textSecondary, size: 16),
                ],
              ],
            ),
          ),
        ),
        if (_birthdateLocked) ...[
          const SizedBox(height: 6),
          Text(
            'Tanggal lahir terkunci. Hubungi admin untuk koreksi.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
    final saveButton = PrimaryButton(
      label: 'Simpan',
      isLoading: state.isSubmitting,
      onPressed: _save,
    );

    // Layar lebar: kartu foto di kiri, field dalam grid 2 kolom di kanan —
    // bukan form sempit di tengah dengan ruang kosong di kiri-kanan.
    if (MediaQuery.sizeOf(context).width >= 900) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profil')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: NeuCard(
                      padding: const EdgeInsets.all(24),
                      radius: 22,
                      child: Column(
                        children: [
                          avatar,
                          const SizedBox(height: 16),
                          Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name
                                  : 'Sahabat Rehat',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.titleLarge),
                          const SizedBox(height: 4),
                          Text('Ketuk foto untuk mengganti',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ResponsiveGrid(
                          minItemWidth: 300,
                          maxColumns: 2,
                          spacing: 20,
                          runSpacing: 18,
                          children: [nameField, phoneField, birthField],
                        ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(width: 240, child: saveButton),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: avatar),
                  const SizedBox(height: 28),
                  nameField,
                  const SizedBox(height: 18),
                  phoneField,
                  const SizedBox(height: 18),
                  birthField,
                  const SizedBox(height: 32),
                  saveButton,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
