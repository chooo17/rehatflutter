import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../data/finance_repository.dart';

/// Kelola biaya tetap bulanan (sewa, gaji, listrik, wifi).
/// Angka di sini menentukan laba bersih DAN break-even — bukan sekadar catatan.
class FixedCostsScreen extends ConsumerWidget {
  const FixedCostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fixedCostsProvider);
    final items = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Biaya Tetap Bulanan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      // Keep-previous-data: spinner hanya saat benar-benar belum ada data.
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(fixedCostsProvider),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // NeuCard SUDAH memberi padding 16 secara bawaan —
                  // jangan bungkus lagi dengan Padding (padding ganda).
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total per bulan',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.rupiah(
                              items.where((e) => e.isActive).fold<int>(0, (s, e) => s + e.amount)),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: AppColors.espresso),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dipakai untuk menghitung laba bersih dan break-even harian.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Belum ada biaya tetap.\nTambahkan sewa, gaji, listrik, dan wifi '
                        'supaya laba bersih tidak terlalu optimis.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final c in items)
                    NeuCard(
                      // ListTile membawa padding sendiri -> matikan padding kartu.
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: Text([
                          if (c.category.isNotEmpty) c.category,
                          if (c.dueDay != null) 'jatuh tempo tgl ${c.dueDay}',
                        ].join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Formatters.rupiah(c.amount)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(context, ref, c),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, FixedCost c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus biaya tetap?'),
        content: Text(
            '${c.name} (${Formatters.rupiah(c.amount)}) akan dihapus. '
            'Laba bersih dan break-even akan ikut berubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(financeRepositoryProvider).deleteFixedCost(c.id);
    ref.invalidate(fixedCostsProvider);
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama biaya (mis. Sewa)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nominal per bulan (Rp)'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
                  if (n == null || n <= 0) return 'Nominal harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Kategori (opsional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await ref.read(financeRepositoryProvider).addFixedCost(
                          name: nameCtrl.text,
                          amount: int.parse(
                              amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')),
                          category: categoryCtrl.text,
                        );
                    ref.invalidate(fixedCostsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
