import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/route_optimizer.dart';

class DriverRouteMap extends StatelessWidget {
  final RouteData routeData;
  final bool compact;
  final String? driverName;

  const DriverRouteMap({
    super.key,
    required this.routeData,
    this.compact = false,
    this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    if (routeData.isEmpty) return const SizedBox.shrink();

    if (compact) {
      return Column(
        children: [
          // Header info bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 16,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rute Pengiriman',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                _chip(
                  Icons.straighten_rounded,
                  'Total ${routeData.totalDistanceKm.toStringAsFixed(1)} km',
                  const Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                _chip(
                  Icons.flag_rounded,
                  '${routeData.stopCount} titik',
                  const Color(0xFFF97316),
                ),
              ],
            ),
          ),
          Expanded(child: _buildMap(context)),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.route_rounded,
            color: Color(0xFF2563EB),
            size: 22,
          ),
        ),
        title: Text(
          'Rute Pengiriman (${routeData.stopCount} tujuan)',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Row(
          children: [
            _chip(
              Icons.straighten_rounded,
              'Total ~${routeData.totalDistanceKm.toStringAsFixed(1)} km',
              const Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            _chip(
              Icons.flag_rounded,
              '${routeData.stopCount} titik',
              const Color(0xFFF97316),
            ),
          ],
        ),
        children: [SizedBox(height: 300, child: _buildMap(context))],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final allPoints = [
      routeData.start,
      ...routeData.orderedStops.map((s) => s.coordinates),
    ];

    // Hitung bounds
    double minLat = allPoints
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLat = allPoints
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    double minLng = allPoints
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLng = allPoints
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    // Padding
    final padLat = (maxLat - minLat) * 0.15 + 0.005;
    final padLng = (maxLng - minLng) * 0.15 + 0.005;
    final bounds = LatLngBounds(
      LatLng(minLat - padLat, minLng - padLng),
      LatLng(maxLat + padLat, maxLng + padLng),
    );

    // Polyline points: start → stop1 → stop2 → ...
    final polyPoints = [routeData.start, ...routeData.orderedStops.map((s) => s.coordinates)];

    // Build markers
    final markers = <Marker>[];

    // Origin marker
    final isOriginCabang = routeData.startIsCabang;
    markers.add(
      Marker(
        point: routeData.start,
        width: 160,
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              child: Text(
                routeData.startName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isOriginCabang
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFF10B981),
                  shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );

    // Stop markers (numbered untuk penerima, warehouse icon untuk cabang)
    for (final stop in routeData.orderedStops) {
      markers.add(
        Marker(
          point: stop.coordinates,
          width: 160,
          height: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: Text(
                  stop.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF97316),
                    shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              if (stop.isCabang)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${stop.orderIndex + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
        maxZoom: 18,
        minZoom: 4,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.tracker',
        ),
        PolylineLayer(
          polylines: [
            Polyline<Object>(
              points: polyPoints,
              color: const Color(0xFF2563EB).withValues(alpha: 0.7),
              strokeWidth: 3.5,
            ),
          ],
        ),
        MarkerLayer(markers: markers),
      ],
    );
    }
}
