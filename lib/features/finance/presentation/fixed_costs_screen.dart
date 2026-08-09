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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddFixedCostSheet(ref: ref),
    );
  }
}

/// StatefulWidget terpisah supaya controller punya lifecycle jelas dan
/// dibuang lewat dispose() -- termasuk saat sheet ditutup dengan swipe
/// (bukan hanya lewat tombol Simpan).
class _AddFixedCostSheet extends StatefulWidget {
  const _AddFixedCostSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_AddFixedCostSheet> createState() => _AddFixedCostSheetState();
}

class _AddFixedCostSheetState extends State<_AddFixedCostSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _dueDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final category = _categoryCtrl.text.trim();
    final dueDayText = _dueDayCtrl.text.trim();
    await widget.ref.read(financeRepositoryProvider).addFixedCost(
          name: _nameCtrl.text,
          amount: int.parse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')),
          category: category.isEmpty ? null : category,
          dueDay: dueDayText.isEmpty ? null : int.parse(dueDayText),
        );
    widget.ref.invalidate(fixedCostsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama biaya (mis. Sewa)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
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
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: 'Kategori (opsional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dueDayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tanggal jatuh tempo (opsional)',
                hintText: '1-31',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                if (n == null || n < 1 || n > 31) {
                  return 'Tanggal jatuh tempo harus antara 1-31';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: _submit,
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
