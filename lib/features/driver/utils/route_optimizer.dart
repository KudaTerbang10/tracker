import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../../data/models/transaction.dart';

class RouteStop {
  final Transaction transaction;
  final LatLng coordinates;
  int orderIndex;

  RouteStop({
    required this.transaction,
    required this.coordinates,
    this.orderIndex = 0,
  });

  String get label => 'Tujuan ${orderIndex + 1}';
  String get name => transaction.penerimaName;
  String get address => transaction.penerimaAddress;
  String get noResi => transaction.noResi;
}

class RouteData {
  final LatLng start;
  final String startName;
  final List<RouteStop> orderedStops;
  final double totalDistanceKm;

  RouteData({
    required this.start,
    required this.startName,
    required this.orderedStops,
    required this.totalDistanceKm,
  });

  bool get isEmpty => orderedStops.isEmpty;
  int get stopCount => orderedStops.length;
}

double haversine(LatLng a, LatLng b) {
  const R = 6371;
  final dLat = _toRad(b.latitude - a.latitude);
  final dLon = _toRad(b.longitude - a.longitude);
  final lat1 = _toRad(a.latitude);
  final lat2 = _toRad(b.latitude);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * R * asin(sqrt(h));
}

double _toRad(double deg) => deg * pi / 180;

List<RouteStop> nearestNeighbor(LatLng start, List<RouteStop> stops) {
  if (stops.isEmpty) return [];
  if (stops.length == 1) {
    stops[0].orderIndex = 0;
    return stops;
  }

  final unvisited = stops.toList();
  final ordered = <RouteStop>[];
  var current = start;

  while (unvisited.isNotEmpty) {
    var nearestIdx = 0;
    var nearestDist = double.infinity;

    for (var i = 0; i < unvisited.length; i++) {
      final dist = haversine(current, unvisited[i].coordinates);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }

    final nearest = unvisited.removeAt(nearestIdx);
    nearest.orderIndex = ordered.length;
    ordered.add(nearest);
    current = nearest.coordinates;
  }

  return ordered;
}
