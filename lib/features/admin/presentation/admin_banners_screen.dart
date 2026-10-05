import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/banner_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/web_safe_image.dart';
import '../../banners/data/banner_repository.dart';

/// (Admin) Kelola banner promo beranda: tambah, edit, aktif/nonaktif, hapus.
class AdminBannersScreen extends ConsumerWidget {
  const AdminBannersScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminBannersProvider);
    ref.invalidate(activeBannersProvider); // agar beranda ikut ter-update
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminBannersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Banner')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.espresso,
        foregroundColor: AppColors.crema,
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Banner'),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat banner.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => _refresh(ref),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (banners) {
          if (banners.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined,
                        size: 40, color: AppColors.amberDark),
                    const SizedBox(height: 12),
                    Text('Belum ada banner', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 6),
                    Text('Tekan tombol + untuk menambah promo di beranda.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return ResponsiveListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: banners.length,
            minItemWidth: 420,
            maxColumns: 3,
            runSpacing: 12,
            itemBuilder: (context, i) => _BannerRow(
              banner: banners[i],
              onEdit: () => _openForm(context, ref, banner: banners[i]),
              onToggle: (v) => _toggle(context, ref, banners[i], v),
              onDelete: () => _confirmDelete(context, ref, banners[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, BannerModel b, bool active) async {
    try {
      await ref.read(bannerRepositoryProvider).update(b.id, {'is_active': active});
      _refresh(ref);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui status.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, BannerModel b) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus banner', style: AppTextStyles.headline),
        content: Text('Hapus "${b.title}"?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: AppTextStyles.label.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(bannerRepositoryProvider).delete(b.id);
      _refresh(ref);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus banner.')),
        );
      }
    }
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {BannerModel? banner}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BannerForm(banner: banner),
    );
    if (saved == true) _refresh(ref);
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({
    required this.banner,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final BannerModel banner;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        children: [
          NeuInset(
            padding: EdgeInsets.zero,
            radius: 12,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                banner.hasImage ? Icons.image_rounded : Icons.campaign_rounded,
                color: AppColors.amberDark,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(banner.title,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (banner.subtitle.isNotEmpty)
                  Text(banner.subtitle,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Switch(
            value: banner.isActive,
            activeThumbColor: AppColors.amber,
            onChanged: onToggle,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Form tambah/edit banner (bottom sheet).
class _BannerForm extends ConsumerStatefulWidget {
  const _BannerForm({this.banner});
  final BannerModel? banner;

  @override
  ConsumerState<_BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends ConsumerState<_BannerForm> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sortOrder;
  bool _active = true;
  bool _saving = false;
  bool _uploading = false;

  bool get _isEdit => widget.banner != null;

  Future<void> _pickAndUpload() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref
          .read(bannerRepositoryProvider)
          .uploadImage(bytes: bytes, filename: picked.name);
      if (!mounted) return;
      setState(() {
        _imageUrl.text = url;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengunggah gambar.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final b = widget.banner;
    _title = TextEditingController(text: b?.title ?? '');
    _subtitle = TextEditingController(text: b?.subtitle ?? '');
    _imageUrl = TextEditingController(text: b?.imageUrl ?? '');
    _sortOrder = TextEditingController(text: (b?.sortOrder ?? 0).toString());
    _active = b?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _imageUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul wajib diisi.')),
      );
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'title': title,
      'subtitle': _subtitle.text.trim(),
      'image_url': _imageUrl.text.trim(),
      'is_active': _active,
      'sort_order': int.tryParse(_sortOrder.text.trim()) ?? 0,
    };
    try {
      final repo = ref.read(bannerRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.banner!.id, body);
      } else {
        await repo.create(body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan banner.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit Banner' : 'Banner Baru',
                style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitle,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Subjudul (opsional)'),
            ),
            const SizedBox(height: 16),
            Text('Gambar Banner (opsional)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            // Preview gambar terpilih / tersimpan.
            if (_imageUrl.text.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: WebSafeImage(
                    url: _imageUrl.text,
                    fit: BoxFit.cover,
                    placeholder: Container(color: AppColors.crema),
                    error: Container(
                      color: AppColors.crema,
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.crema,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Belum ada gambar (kartu gradien)',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    onPressed: _uploading ? null : _pickAndUpload,
                    child: _uploading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: AppColors.amber))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_rounded,
                                  size: 18, color: AppColors.espresso),
                              const SizedBox(width: 8),
                              Text(
                                  _imageUrl.text.isEmpty
                                      ? 'Upload Gambar'
                                      : 'Ganti Gambar',
                                  style: AppTextStyles.button
                                      .copyWith(color: AppColors.espresso)),
                            ],
                          ),
                  ),
                ),
                if (_imageUrl.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _imageUrl.clear()),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                    tooltip: 'Hapus gambar',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Urutan',
                hintText: 'Angka kecil tampil lebih dulu',
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Aktif', style: AppTextStyles.bodyLarge),
              value: _active,
              activeThumbColor: AppColors.amber,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            NeuButton(
              expand: true,
              accent: true,
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : Text(_isEdit ? 'Simpan' : 'Tambah',
                      style:
                          AppTextStyles.button.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
