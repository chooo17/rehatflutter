// lib/features/delivery/presentation/store_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/delivery_models.dart';
import '../data/delivery_repository.dart';
import 'widgets/location_picker.dart';

/// Parse angka isian admin: buang '.', ',' dan spasi (pemisah ribuan).
int? parseStoreNumber(String s) => int.tryParse(s.replaceAll(RegExp(r'[.,\s]'), ''));

/// Validasi isian pengaturan toko. Mengembalikan pesan galat, atau null bila valid.
String? validateStoreSettingsInput({
  required String radius,
  required String fee,
  required String freeMin,
  required String cutoff,
  required String address,
}) {
  final r = parseStoreNumber(radius);
  if (r == null || r < 500 || r > 20000) return 'Radius harus 500–20.000 meter.';
  final f = parseStoreNumber(fee);
  if (f == null || f < 0 || f > 100000) return 'Ongkir harus Rp 0–100.000.';
  final m = parseStoreNumber(freeMin);
  if (m == null || m < 0 || m > 10000000) return 'Gratis ongkir harus Rp 0–10.000.000.';
  final c = parseStoreNumber(cutoff);
  if (c == null || c < 0 || c > 240) return 'Batas sebelum tutup harus 0–240 menit.';
  if (address.trim().length > 300) return 'Alamat toko maksimal 300 karakter.';
  return null;
}

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

  @override
  void dispose() {
    _radius.dispose();
    _fee.dispose();
    _freeMin.dispose();
    _cutoff.dispose();
    _address.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  bool _validTime(String? t) => t != null && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(t);

  Future<void> _save() async {
    for (final h in _hours) {
      if (!h.isClosed && (!_validTime(h.openTime) || !_validTime(h.closeTime))) {
        return _toast('Jam ${StoreHour.dayNames[h.dayOfWeek]} harus format JJ:MM (24.00 ditulis 00:00)');
      }
    }
    final invalid = validateStoreSettingsInput(
        radius: _radius.text,
        fee: _fee.text,
        freeMin: _freeMin.text,
        cutoff: _cutoff.text,
        address: _address.text);
    if (invalid != null) return _toast(invalid);
    final s = StoreSettings(
      storeLat: _point.latitude,
      storeLng: _point.longitude,
      storeAddress: _address.text.trim(),
      deliveryEnabled: _enabled,
      radiusM: parseStoreNumber(_radius.text)!,
      deliveryFee: parseStoreNumber(_fee.text)!,
      freeDeliveryMin: parseStoreNumber(_freeMin.text)!,
      cutoffMinutes: parseStoreNumber(_cutoff.text)!,
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
    } catch (_) {
      _toast('Gagal menyimpan pengaturan.');
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
    String? phone;
    try {
      phone = await showDialog<String>(
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
    } finally {
      // Tunda: animasi tutup dialog masih memakai controller sesaat.
      Future.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    }
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
