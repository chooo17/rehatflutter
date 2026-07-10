import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../home/data/home_repository.dart';
import '../../menu/data/menu_repository.dart';

/// (Admin) Kelola gambar menu: pilih item, unggah/ganti fotonya.
class AdminMenuImagesScreen extends ConsumerStatefulWidget {
  const AdminMenuImagesScreen({super.key});

  @override
  ConsumerState<AdminMenuImagesScreen> createState() =>
      _AdminMenuImagesScreenState();
}

class _AdminMenuImagesScreenState extends ConsumerState<AdminMenuImagesScreen> {
  String? _uploadingId;

  Future<void> _pickAndUpload(MenuItemModel item) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingId = item.id);
    try {
      final bytes = await picked.readAsBytes();
      await ref.read(menuRepositoryProvider).uploadItemImage(
            itemId: item.id,
            bytes: bytes,
            filename: picked.name,
          );
      // Segarkan semua tampilan menu.
      ref.invalidate(allMenuItemsProvider);
      ref.invalidate(menuListProvider);
      ref.invalidate(featuredMenuProvider);
      ref.invalidate(menuDetailProvider(item.id));
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gambar "${item.name}" diperbarui')));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal mengunggah gambar.')));
    } finally {
      if (mounted) setState(() => _uploadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allMenuItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Gambar Menu')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat menu.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.invalidate(allMenuItemsProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (items) => RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => ref.invalidate(allMenuItemsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ItemRow(
              item: items[i],
              uploading: _uploadingId == items[i].id,
              onTap: () => _pickAndUpload(items[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.uploading,
    required this.onTap,
  });
  final MenuItemModel item;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: uploading
                    ? Container(
                        color: AppColors.crema,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: AppColors.amber),
                          ),
                        ),
                      )
                    : (item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.crema),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.crema,
                              child: const Icon(Icons.image_not_supported_outlined,
                                  color: AppColors.amber),
                            ),
                          )
                        : Container(
                            color: AppColors.crema,
                            child: Icon(Icons.add_photo_alternate_outlined,
                                color: AppColors.amberDark),
                          )),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? 'Ketuk untuk ganti gambar'
                        : 'Belum ada gambar — ketuk untuk unggah',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.upload_rounded, color: AppColors.amberDark, size: 20),
          ],
        ),
      ),
    );
  }
}
