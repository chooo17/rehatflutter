// lib/features/delivery/presentation/address_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/models/delivery_models.dart';
import '../data/delivery_repository.dart';

class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, AddressModel a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus alamat?'),
        content: Text(a.label),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(deliveryRepositoryProvider).deleteAddress(a.id);
      ref.invalidate(addressesProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.addressForm),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah alamat'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: TextButton(onPressed: () => ref.invalidate(addressesProvider), child: const Text('Gagal memuat. Coba lagi'))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Belum ada alamat tersimpan.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = list[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(a.isDefault ? Icons.home_rounded : Icons.location_on_outlined),
                      title: Text(a.isDefault ? '${a.label} • Utama' : a.label),
                      subtitle: Text('${a.addressText}\n${a.recipientName} • ${a.recipientPhone}'),
                      isThreeLine: true,
                      onTap: () => context.pushNamed(RouteNames.addressForm, extra: a),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(context, ref, a),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
