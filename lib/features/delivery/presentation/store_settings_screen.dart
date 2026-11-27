// lib/features/delivery/presentation/store_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/delivery_models.dart';
import '../data/delivery_repository.dart';
import 'widgets/location_picker.dart';

/// Admin: saklar delivery, radius, ongkir, jam buka, dan daftar kurir.
class StoreSettingsScreen extends ConsumerWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storeSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery & Kurir')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: TextButton(onPressed: () => ref.invalidate(storeSettingsProvider), child: const Text('Gagal memuat. Coba lagi'))),
        data: (d) => _SettingsForm(settings: d.$1, hours: d.$2),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings, required this.hours});
  final StoreSettings settings;
  final List<StoreHour> hours;
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late bool _enabled = widget.settings.deliveryEnabled;
  late final _radius = TextEditingController(text: '${widget.settings.radiusM}');
  late final _fee = TextEditingController(text: '${widget.settings.deliveryFee}');
  late final _freeMin = TextEditingController(text: '${widget.settings.freeDeliveryMin}');
  late final _cutoff = TextEditingController(text: '${widget.settings.cutoffMinutes}');
  late final _address = TextEditingController(text: widget.settings.storeAddress);
  late LatLng _point = widget.settings.storeLat == null
      ? rehatStoreLatLng
      : LatLng(widget.settings.storeLat!, widget.settings.storeLng!);
  late List<StoreHour> _hours = widget.hours.length == 7
      ? widget.hours
      : [for (var d = 0; d < 7; d++) StoreHour(dayOfWeek: d, openTime: '10:00', closeTime: '00:00')];
  bool _saving = false;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  bool _validTime(String? t) => t != null && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(t);

  Future<void> _save() async {
    for (final h in _hours) {
      if (!h.isClosed && (!_validTime(h.openTime) || !_validTime(h.closeTime))) {
        return _toast('Jam ${StoreHour.dayNames[h.dayOfWeek]} harus format JJ:MM (24.00 ditulis 00:00)');
      }
    }
    final s = StoreSettings(
      storeLat: _point.latitude,
      storeLng: _point.longitude,
      storeAddress: _address.text.trim(),
      deliveryEnabled: _enabled,
      radiusM: int.tryParse(_radius.text) ?? widget.settings.radiusM,
      deliveryFee: int.tryParse(_fee.text) ?? widget.settings.deliveryFee,
      freeDeliveryMin: int.tryParse(_freeMin.text) ?? widget.settings.freeDeliveryMin,
      cutoffMinutes: int.tryParse(_cutoff.text) ?? widget.settings.cutoffMinutes,
    );
    setState(() => _saving = true);
    try {
      final repo = ref.read(deliveryRepositoryProvider);
      await repo.updateStoreSettings(s);
      await repo.saveStoreHours(_hours);
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(deliveryConfigProvider);
      _toast('Pengaturan disimpan');
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _num(TextEditingController c, String label) => TextField(
      controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
          title: Text('Delivery aktif', style: AppTextStyles.titleMedium),
          subtitle: const Text('Matikan untuk menutup delivery sementara.'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _num(_radius, 'Radius (meter)')),
          const SizedBox(width: 12),
          Expanded(child: _num(_cutoff, 'Batas sebelum tutup (menit)')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _num(_fee, 'Ongkir (Rp)')),
          const SizedBox(width: 12),
          Expanded(child: _num(_freeMin, 'Gratis ongkir mulai (Rp)')),
        ]),
        const SizedBox(height: 20),
        Text('Titik toko', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        LocationPicker(initial: _point, onChanged: (ll) => setState(() => _point = ll), height: 220),
        const SizedBox(height: 8),
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Alamat toko')),
        const SizedBox(height: 20),
        Text('Jam buka (WIB)', style: AppTextStyles.titleMedium),
        for (var i = 0; i < _hours.length; i++)
          _HourRow(
            hour: _hours[i],
            onChanged: (h) => setState(() => _hours = [..._hours]..[i] = h),
          ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan…' : 'Simpan pengaturan')),
        const SizedBox(height: 28),
        const _CouriersSection(),
      ],
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({required this.hour, required this.onChanged});
  final StoreHour hour;
  final ValueChanged<StoreHour> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        SizedBox(width: 64, child: Text(StoreHour.dayNames[hour.dayOfWeek])),
        Expanded(
          child: TextFormField(
            initialValue: hour.openTime,
            enabled: !hour.isClosed,
            decoration: const InputDecoration(labelText: 'Buka', hintText: '10:00'),
            onChanged: (v) => onChanged(hour.copyWith(openTime: v.trim())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: hour.closeTime,
            enabled: !hour.isClosed,
            decoration: const InputDecoration(labelText: 'Tutup', hintText: '00:00'),
            onChanged: (v) => onChanged(hour.copyWith(closeTime: v.trim())),
          ),
        ),
        const SizedBox(width: 4),
        Column(children: [
          const Text('Libur', style: TextStyle(fontSize: 12)),
          Switch(value: hour.isClosed, onChanged: (v) => onChanged(hour.copyWith(isClosed: v))),
        ]),
      ]),
    );
  }
}

class _CouriersSection extends ConsumerWidget {
  const _CouriersSection();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tambah kurir'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'No. HP akun kurir', helperText: 'Kurir harus sudah daftar di app sebagai pelanggan'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Tambah')),
        ],
      ),
    );
    if (phone == null || phone.isEmpty) return;
    try {
      await ref.read(deliveryRepositoryProvider).addCourier(phone);
      ref.invalidate(couriersProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, CourierInfo k) async {
    try {
      await ref.read(deliveryRepositoryProvider).removeCourier(k.id);
      ref.invalidate(couriersProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(couriersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Kurir', style: AppTextStyles.titleMedium),
          const Spacer(),
          TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Tambah')),
        ]),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const Text('Gagal memuat kurir.'),
          data: (list) => list.isEmpty
              ? const Text('Belum ada kurir.')
              : Column(children: [
                  for (final k in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.circle, size: 12, color: k.onDuty ? Colors.green : Colors.grey),
                      title: Text(k.name.isEmpty ? k.phone : k.name),
                      subtitle: Text('${k.phone} • ${k.onDuty ? 'bertugas' : 'tidak bertugas'}'),
                      trailing: IconButton(icon: const Icon(Icons.person_remove_outlined), onPressed: () => _remove(context, ref, k)),
                    ),
                ]),
        ),
      ],
    );
  }
}
