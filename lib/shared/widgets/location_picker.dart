import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String? address;

  LocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class LocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  static Future<LocationPickerResult?> show(BuildContext context, {double? latitude, double? longitude, String? address}) {
    return Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LocationPicker(
          initialLatitude: latitude,
          initialLongitude: longitude,
          initialAddress: address,
        ),
      ),
    );
  }

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late MapController _mapController;
  late LatLng _center;
  LatLng? _marker;
  String? _address;
  bool _loadingAddress = false;
  final _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _center = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _marker = _center;
      _reverseGeocode(_center);
    } else {
      // default center Indonesia
      _center = const LatLng(-2.0, 118.0);
    }
    // Pre-fill search with initial address and auto-search
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _searchC.text = widget.initialAddress!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchAddress());
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': pos.latitude.toString(),
          'lon': pos.longitude.toString(),
          'format': 'json',
          'accept-language': 'id',
        },
        options: Options(
          headers: {'User-Agent': 'TrackerApp/1.0'},
        ),
      );
      final displayName = res.data['display_name'] as String?;
      if (mounted) setState(() => _address = displayName);
    } catch (_) {
      if (mounted) setState(() => _address = null);
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _searchAddress() async {
    final q = _searchC.text.trim();
    if (q.isEmpty) return;

    setState(() => _loadingAddress = true);
    try {
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'json',
          'limit': 1,
          'accept-language': 'id',
        },
        options: Options(
          headers: {'User-Agent': 'TrackerApp/1.0'},
        ),
      );
      final data = res.data;
      if (data is List && data.isNotEmpty) {
        final lat = double.parse(data[0]['lat'] as String);
        final lon = double.parse(data[0]['lon'] as String);
        final pos = LatLng(lat, lon);
        setState(() {
          _center = pos;
          _marker = pos;
          _address = data[0]['display_name'] as String?;
        });
        _mapController.move(pos, 16);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mencari lokasi')),
      );
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  void _onMapTapped(TapPosition tap, LatLng pos) {
    setState(() {
      _center = pos;
      _marker = pos;
    });
    _reverseGeocode(pos);
  }

  void _confirm() {
    if (_marker == null) return;
    Navigator.of(context).pop(LocationPickerResult(
      latitude: _marker!.latitude,
      longitude: _marker!.longitude,
      address: _address,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        actions: [
          if (_marker != null)
            TextButton(
              onPressed: _confirm,
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchC,
              decoration: InputDecoration(
                labelText: 'Cari Alamat',
                hintText: 'Atur pinpoint dengan akurat',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  onPressed: _searchAddress,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _marker != null ? 16 : 5,
                    onTap: _onMapTapped,
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        final center = _mapController.camera.center;
                        setState(() {
                          _center = center;
                          _marker = center;
                        });
                        _reverseGeocode(center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tracker',
                    ),
                    if (_marker != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _marker!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Address bubble
                if (_marker != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _loadingAddress
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_marker!.latitude.toStringAsFixed(6)}, ${_marker!.longitude.toStringAsFixed(6)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (_address != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _address!,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocationPreviewTile extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String address;

  const LocationPreviewTile({
    super.key,
    this.latitude,
    this.longitude,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoords = latitude != null && longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: hasCoords ? Colors.red : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: const Text('Alamat', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
            Expanded(
              child: Text(
                address,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        if (hasCoords) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 150,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(latitude!, longitude!),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tracker',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(latitude!, longitude!),
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
