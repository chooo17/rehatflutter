import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/neu.dart';
import '../application/printer_controller.dart';
import '../data/printer_bridge.dart';
import '../data/receipt_template.dart';

/// (Admin) Pengaturan printer thermal Bluetooth & template struk.
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState
    extends ConsumerState<PrinterSettingsScreen> {
  final _templateCtrl = TextEditingController();
  bool _templateLoaded = false;

  @override
  void initState() {
    super.initState();
    // Status koneksi bisa sudah basi sejak terakhir dilihat — periksa ulang
    // saat layar dibuka supaya badge "Tersambung" dan tombol "Tes Cetak"
    // mencerminkan keadaan printer yang sebenarnya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(printerControllerProvider.notifier).refreshConnection();
    });
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPrinter() async {
    final ctrl = ref.read(printerControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Mencari printer ter-pairing…')));
    final list = await ctrl.listPaired();
    if (!mounted) return;
    if (list.isEmpty) {
      _snack('Tak ada printer ter-pairing. Pairing dulu di Pengaturan Bluetooth HP.');
      return;
    }
    final chosen = await showModalBottomSheet<BtPrinter>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Pilih Printer', style: AppTextStyles.titleLarge),
            ),
            for (final p in list)
              ListTile(
                leading: Icon(Icons.print_rounded, color: AppColors.amberDark),
                title: Text(p.name.isEmpty ? '(tanpa nama)' : p.name,
                    style: AppTextStyles.bodyLarge),
                subtitle: Text(p.address, style: AppTextStyles.caption),
                onTap: () => Navigator.pop(context, p),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    final ok = await ctrl.connectTo(chosen);
    if (!mounted) return;
    _snack(ok ? 'Tersambung ke ${chosen.name}' : 'Gagal menyambung printer.');
  }

  Future<void> _testPrint() async {
    final ctrl = ref.read(printerControllerProvider.notifier);
    final ok = await ctrl.printRaw(
        '#REHAT COFFEEHOUSE\n@Tes cetak struk\n--------------------------------\nJika ini tercetak, printer siap!\n');
    if (!mounted) return;
    _snack(ok ? 'Tes cetak terkirim.' : 'Gagal mencetak. Cek koneksi printer.');
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 90,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      await ref.read(receiptLogoProvider.notifier).save(bytes);
      if (mounted) _snack('Logo struk disimpan.');
    } catch (_) {
      if (mounted) _snack('Gagal menyimpan logo.');
    }
  }

  Future<void> _saveTemplate() async {
    await ref
        .read(receiptTemplateProvider.notifier)
        .save(_templateCtrl.text);
    if (!mounted) return;
    _snack('Template struk disimpan.');
  }

  Future<void> _resetTemplate() async {
    await ref.read(receiptTemplateProvider.notifier).resetToDefault();
    _templateCtrl.text = defaultReceiptTemplate;
    if (!mounted) return;
    _snack('Template dikembalikan ke bawaan.');
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerControllerProvider);
    final templateAsync = ref.watch(receiptTemplateProvider);
    // Isi editor sekali saat template pertama termuat.
    templateAsync.whenData((t) {
      if (!_templateLoaded) {
        _templateCtrl.text = t;
        _templateLoaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Printer & Struk')),
      body: !printer.supported
          ? _UnsupportedNote()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // ── Koneksi printer ──
                Text('Printer Bluetooth', style: AppTextStyles.titleMedium),
                const SizedBox(height: 10),
                NeuCard(
                  padding: const EdgeInsets.all(16),
                  radius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            printer.connected
                                ? Icons.print_rounded
                                : Icons.print_disabled_rounded,
                            color: printer.connected
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              printer.connected
                                  ? 'Tersambung: ${printer.deviceName ?? printer.address ?? "-"}'
                                  : 'Belum tersambung',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: NeuButton(
                              expand: true,
                              accent: true,
                              onPressed:
                                  printer.busy ? null : _pickPrinter,
                              child: Text('Pilih & Sambungkan',
                                  style: AppTextStyles.button
                                      .copyWith(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NeuButton(
                              expand: true,
                              onPressed:
                                  printer.connected ? _testPrint : null,
                              child: Text('Tes Cetak',
                                  style: AppTextStyles.button.copyWith(
                                      color: printer.connected
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Logo struk ──
                Text('Logo Struk', style: AppTextStyles.titleMedium),
                const SizedBox(height: 6),
                Text('Dicetak di tengah paling atas nota (opsional).',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Consumer(builder: (context, ref, _) {
                  final logo = ref.watch(receiptLogoProvider).valueOrNull;
                  return Row(
                    children: [
                      // Preview logo (latar gelap agar logo grayscale terlihat).
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.crema,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: logo != null
                            ? Image.memory(logo, fit: BoxFit.contain)
                            : Icon(Icons.image_outlined,
                                color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeuButton(
                          onPressed: _pickLogo,
                          child: Text(logo == null ? 'Upload Logo' : 'Ganti Logo',
                              style: AppTextStyles.button
                                  .copyWith(color: AppColors.espresso)),
                        ),
                      ),
                      if (logo != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              ref.read(receiptLogoProvider.notifier).clear(),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error),
                          tooltip: 'Hapus logo',
                        ),
                      ],
                    ],
                  );
                }),
                const SizedBox(height: 24),
                // ── Template struk ──
                Row(
                  children: [
                    Text('Format Struk', style: AppTextStyles.titleMedium),
                    const Spacer(),
                    TextButton(
                        onPressed: _resetTemplate,
                        child: const Text('Reset')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Placeholder: {antrian} {tanggal} {nama} {metode} {items} {total}. '
                  'Awali baris dengan # (judul besar) atau @ (rata tengah).',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                NeuInset(
                  padding: const EdgeInsets.all(12),
                  radius: 14,
                  child: TextField(
                    controller: _templateCtrl,
                    maxLines: 14,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Template struk…',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                NeuButton(
                  expand: true,
                  accent: true,
                  onPressed: _saveTemplate,
                  child: Text('Simpan Template',
                      style:
                          AppTextStyles.button.copyWith(color: Colors.white)),
                ),
              ],
            ),
    );
  }
}

class _UnsupportedNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Cetak struk hanya di aplikasi Android',
                textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
            const SizedBox(height: 6),
            Text(
                'Printer thermal Bluetooth tidak tersedia di versi web. '
                'Gunakan aplikasi Android untuk mencetak struk.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
