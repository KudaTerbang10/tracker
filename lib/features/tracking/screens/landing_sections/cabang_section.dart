import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/cabang_lokasi_service.dart';

class CabangSection extends StatefulWidget {
  final GlobalKey sectionKey;
  const CabangSection({super.key, required this.sectionKey});

  @override
  State<CabangSection> createState() => CabangSectionState();
}

class _CabangGrid extends StatelessWidget {
  final int crossAxisCount;
  final double padding;
  final List<Widget> cards;

  const _CabangGrid({
    required this.crossAxisCount,
    required this.padding,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final gap = 16.0;
    final rows = <Widget>[];

    for (var i = 0; i < cards.length; i += crossAxisCount) {
      final end = (i + crossAxisCount > cards.length) ? cards.length : i + crossAxisCount;
      final rowCards = cards.sublist(i, end);
      final lastRow = i + crossAxisCount >= cards.length;

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: lastRow ? 0 : gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(rowCards.length, (j) {
                final isLast = j == rowCards.length - 1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : gap),
                    child: rowCards[j],
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

class CabangSectionState extends State<CabangSection> {
  bool _locating = false;
  bool _locationError = false;
  Position? _userPosition;
  List<CabangTerdekat> _cabangTerdekat = [];
  final _cabangMapController = MapController();
  bool _cabangMapReady = false;
  double _cabangInitZoom = 13;
  LatLng? _cabangMapCenter;

  Future<void> cariCabangTerdekat() async {
    setState(() {
      _locating = true;
      _locationError = false;
      _cabangTerdekat = [];
    });

    try {
      final locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        final granted = await Geolocator.requestPermission();
        if (granted == LocationPermission.denied ||
            granted == LocationPermission.deniedForever) {
          setState(() {
            _locating = false;
            _locationError = true;
          });
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final hasil = CabangLokasiService.cariTerdekat(
        userLat: pos.latitude,
        userLng: pos.longitude,
        radiusKm: 20.0,
      );

      double zoom = 13;
      if (hasil.isNotEmpty) {
        final nearest = hasil.first.cabang;
        final diffLat = (pos.latitude - nearest.latitude!).abs();
        final diffLng = (pos.longitude - nearest.longitude!).abs();
        final diffMax = diffLat > diffLng ? diffLat : diffLng;
        if (diffMax > 0.5) {
          zoom = 9;
        } else if (diffMax > 0.2) {
          zoom = 10;
        } else if (diffMax > 0.1) {
          zoom = 11;
        } else if (diffMax > 0.05) {
          zoom = 12;
        }
      }

      setState(() {
        _userPosition = pos;
        _cabangTerdekat = hasil;
        _cabangInitZoom = zoom;
        if (hasil.isNotEmpty) {
          _cabangMapCenter = LatLng(
            (pos.latitude + hasil.first.cabang.latitude!) / 2,
            (pos.longitude + hasil.first.cabang.longitude!) / 2,
          );
        } else {
          _cabangMapCenter = LatLng(pos.latitude, pos.longitude);
        }
        _locating = false;
      });
    } catch (e) {
      setState(() {
        _locating = false;
        _locationError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    Widget header = Column(
      children: [
        Text(
          'Cari Cabang Terdekat',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Temukan cabang Hira Express di sekitar lokasi Anda dalam radius 20 km',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_cabangTerdekat.isEmpty && !_locating && !_locationError)
          _buildCabangCta()
        else if (_locating)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Mencari lokasi Anda...',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else if (_locationError)
          _buildLocationError()
        else
          _buildCabangMap(),
      ],
    );

    return KeyedSubtree(
      key: widget.sectionKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: header,
              ),
            ),
            if (!_locating && !_locationError && _cabangTerdekat.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCabangGrid(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCabangCta() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppTheme.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Izinkan akses lokasi untuk melihat cabang terdekat',
              style: TextStyle(fontSize: 16, color: Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: cariCabangTerdekat,
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Cari Cabang Terdekat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationError() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: Color(0xFFDC2626),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tidak dapat mengakses lokasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan izin lokasi telah diaktifkan',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: cariCabangTerdekat,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabangMap() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final userLatLng = LatLng(
      _userPosition!.latitude,
      _userPosition!.longitude,
    );
    final center = _cabangMapCenter ?? userLatLng;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              SizedBox(
                height: isMobile ? 250 : 350,
                child: FlutterMap(
                  mapController: _cabangMapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _cabangInitZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onMapReady: () {
                      _cabangMapReady = true;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tracker',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: userLatLng,
                          width: 140,
                          height: 60,
                          child: _cabangMarker(
                            'Lokasi Anda',
                            AppTheme.primary,
                            Icons.my_location_rounded,
                            36,
                          ),
                        ),
                        for (final ct in _cabangTerdekat)
                          Marker(
                            point: LatLng(
                              ct.cabang.latitude!,
                              ct.cabang.longitude!,
                            ),
                            width: 180,
                            height: 60,
                            child: _cabangMarker(
                              'Cabang ${ct.cabang.name}',
                              Colors.red,
                              Icons.location_on_rounded,
                              36,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (!_cabangMapReady) return;
                      _cabangMapController.move(
                        LatLng(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                        ),
                        _cabangInitZoom,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.my_location_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _cabangMarker(
    String label,
    Color color,
    IconData icon,
    double size,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.2,
            ),
          ),
        ),
        Icon(icon, color: color, size: size),
      ],
    );
  }

  Widget _buildCabangGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 0.0 : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: isMobile
          ? Column(
              children: _cabangTerdekat
                  .map((ct) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _cabangCard(ct),
                      ))
                  .toList(),
            )
          : _CabangGrid(
              crossAxisCount: screenWidth >= 1200 ? 4 : 2,
              padding: padding,
              cards: _cabangTerdekat.map((ct) => _cabangCard(ct)).toList(),
            ),
    );
  }

  Widget _cabangCard(CabangTerdekat ct) {
    final c = ct.cabang;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ct.jarakLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (c.address.isNotEmpty)
                    Text(
                      c.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (c.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
