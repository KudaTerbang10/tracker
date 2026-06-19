import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/route_optimizer.dart';

class DriverRouteMap extends StatelessWidget {
  final RouteData routeData;
  final bool compact;

  const DriverRouteMap({
    super.key,
    required this.routeData,
    this.compact = false,
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
          Expanded(child: _buildMap()),
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
        children: [SizedBox(height: 300, child: _buildMap())],
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

  Widget _buildMap() {
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

    // Polyline points: cabang → stop1 → stop2 → ...
    // Segmen antar cabang dibuat melengkung
    final pointIsCabang = [
      routeData.startIsCabang,
      ...routeData.orderedStops.map((s) => s.isCabang),
    ];
    final polyPoints = <LatLng>[allPoints[0]];
    for (var i = 1; i < allPoints.length; i++) {
      if (pointIsCabang[i - 1] && pointIsCabang[i]) {
        polyPoints.addAll(_curvePoints(allPoints[i - 1], allPoints[i]).skip(1));
      } else {
        polyPoints.add(allPoints[i]);
      }
    }

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

  /// Quadratic bezier antara dua titik, melengkung secukupnya.
  List<LatLng> _curvePoints(LatLng a, LatLng b) {
    final mid = LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.0001) return [a, b];
    final nx = -dy / len;
    final ny = dx / len;
    const offset = 0.002;
    final cp = LatLng(mid.latitude + nx * offset, mid.longitude + ny * offset);

    const steps = 20;
    return List.generate(steps + 1, (i) {
      final t = i / steps;
      return LatLng(
        (1 - t) * (1 - t) * a.latitude +
            2 * (1 - t) * t * cp.latitude +
            t * t * b.latitude,
        (1 - t) * (1 - t) * a.longitude +
            2 * (1 - t) * t * cp.longitude +
            t * t * b.longitude,
      );
    });
  }
}
