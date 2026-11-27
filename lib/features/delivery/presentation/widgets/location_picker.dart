import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Titik Rehat Coffeehouse (default peta bila belum ada titik).
const rehatStoreLatLng = LatLng(-7.1940555, 113.2508814);

/// Peta dengan pin tetap di tengah: geser peta untuk menandai lokasi.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.initial, required this.onChanged, this.height = 260});

  final LatLng initial;
  final ValueChanged<LatLng> onChanged;
  final double height;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _map = MapController();
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Izin lokasi ditolak. Geser peta untuk menandai lokasi.');
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      final ll = LatLng(p.latitude, p.longitude);
      _map.move(ll, 17);
      widget.onChanged(ll);
    } catch (_) {
      _snack('Lokasi tidak bisa dibaca. Geser peta untuk menandai lokasi.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: widget.initial,
                initialZoom: 16,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) widget.onChanged(camera.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rehat.rehat_app',
                ),
              ],
            ),
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.location_pin, size: 44, color: AppColors.amberDark),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: _locating ? null : _useMyLocation,
                child: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 4,
              child: Container(
                color: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('© OpenStreetMap', style: AppTextStyles.caption.copyWith(color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
