// lib/features/delivery/presentation/address_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/models/delivery_models.dart';
import '../../auth/application/auth_controller.dart';
import '../data/delivery_repository.dart';
import 'widgets/location_picker.dart';

/// Validasi No. HP penerima: hanya angka/+/-/spasi/kurung, 8–25 karakter, ≥8 digit.
String? validateRecipientPhone(String? v) {
  final raw = (v ?? '').trim();
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(raw) || raw.length < 8 || raw.length > 25 || digits < 8) {
    return 'Nomor HP tidak valid';
  }
  return null;
}

/// Tambah / ubah alamat. `existing` null = alamat baru. Pop dengan [AddressModel] tersimpan.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});
  final AddressModel? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label ?? 'Rumah');
  late final _address = TextEditingController(text: widget.existing?.addressText ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late final _name = TextEditingController(
      text: widget.existing?.recipientName ?? ref.read(authControllerProvider).user?.name ?? '');
  late final _phone = TextEditingController(
      text: widget.existing?.recipientPhone ?? ref.read(authControllerProvider).user?.phone ?? '');
  late LatLng _point = widget.existing == null
      ? rehatStoreLatLng
      : LatLng(widget.existing!.lat, widget.existing!.lng);
  late bool _isDefault = widget.existing?.isDefault ?? false;
  bool _pinMoved = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_label, _address, _notes, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.existing == null && !_pinMoved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geser peta atau tekan "Lokasi saya" untuk menandai lokasi alamat.')));
      return;
    }
    setState(() => _saving = true);
    final a = AddressModel(
      label: _label.text.trim(),
      addressText: _address.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      recipientName: _name.text.trim(),
      recipientPhone: _phone.text.trim(),
      lat: _point.latitude,
      lng: _point.longitude,
      isDefault: _isDefault,
    );
    try {
      final repo = ref.read(deliveryRepositoryProvider);
      final saved = widget.existing == null
          ? await repo.createAddress(a)
          : await repo.updateAddress(widget.existing!.id, a);
      ref.invalidate(addressesProvider);
      if (mounted) context.pop(saved);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Tambah alamat' : 'Ubah alamat')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            LocationPicker(
              initial: _point,
              onChanged: (ll) => setState(() {
                _point = ll;
                _pinMoved = true;
              }),
            ),
            const SizedBox(height: 6),
            const Text('Geser peta sampai pin tepat di lokasi pengantaran.'),
            const SizedBox(height: 16),
            TextFormField(controller: _label, maxLength: 30, decoration: const InputDecoration(labelText: 'Label (mis. Rumah, Kantor)'), validator: _required),
            const SizedBox(height: 12),
            TextFormField(controller: _address, maxLines: 2, maxLength: 300, decoration: const InputDecoration(labelText: 'Alamat lengkap'),
                validator: (v) => (v ?? '').trim().length < 5 ? 'Minimal 5 karakter' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLength: 200, decoration: const InputDecoration(labelText: 'Patokan (opsional)', hintText: 'Mis. pagar hijau, lantai 2')),
            const SizedBox(height: 12),
            TextFormField(controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'Nama penerima'), validator: _required),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP penerima'),
                validator: validateRecipientPhone),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const Text('Jadikan alamat utama'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan alamat'),
            ),
          ],
        ),
      ),
    );
  }
}
