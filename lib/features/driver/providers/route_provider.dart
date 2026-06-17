import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/models/transaction.dart';
import '../../auth/providers/auth_provider.dart';
import '../utils/route_optimizer.dart';

final routeProvider = FutureProvider.autoDispose<RouteData?>((ref) async {
  try {
    final user = ref.watch(authProvider).user;
    if (user == null) return null;

    final result = await ref.read(transactionRepositoryProvider).getList(
      status: 'proses_kirim',
      limit: 999,
    );
    final transactions = result['data'] as List<Transaction>;

    // Filter transaksi milik driver ini yang tujuan ke penerima
    final penerimaStops = <RouteStop>[];
    for (final tx in transactions) {
      if (tx.driverUserId != user.id) continue;
      if (tx.tujuanSelanjutnya?['tipe'] != 'penerima') continue;
      if (tx.penerimaLatitude == null || tx.penerimaLongitude == null) continue;

      penerimaStops.add(RouteStop(
        transaction: tx,
        coordinates: LatLng(tx.penerimaLatitude!, tx.penerimaLongitude!),
      ));
    }

    if (penerimaStops.isEmpty) return null;

    // Cari cabang asal dari tracking_logs (keluar_cabang terakhir)
    _CabangInfo? cabang;
    for (final tx in transactions) {
      if (tx.driverUserId != user.id) continue;
      for (final log in tx.trackingLogs.reversed) {
        if (log.status == 'keluar_cabang') {
          final cabangName = log.lokasiName;
          if (cabangName.isNotEmpty) {
            cabang = await _findCabangPosition(cabangName);
            if (cabang != null) break;
          }
        }
      }
      if (cabang != null) break;
    }

    // Fallback: center dari semua penerima
    if (cabang == null && penerimaStops.isNotEmpty) {
      final avgLat = penerimaStops.map((s) => s.coordinates.latitude).reduce((a, b) => a + b) / penerimaStops.length;
      final avgLng = penerimaStops.map((s) => s.coordinates.longitude).reduce((a, b) => a + b) / penerimaStops.length;
      cabang = _CabangInfo(pos: LatLng(avgLat, avgLng), name: 'Lokasi Awal');
    }

    if (cabang == null) return null;

    // Hitung rute nearest neighbor
    final ordered = nearestNeighbor(cabang.pos, penerimaStops);

    // Hitung total jarak
    var total = haversine(cabang.pos, ordered.first.coordinates);
    for (var i = 1; i < ordered.length; i++) {
      total += haversine(ordered[i - 1].coordinates, ordered[i].coordinates);
    }

    return RouteData(
      start: cabang.pos,
      startName: cabang.name,
      orderedStops: ordered,
      totalDistanceKm: total,
    );
  } catch (_) {
    return null;
  }
});

class _CabangInfo {
  final LatLng pos;
  final String name;
  _CabangInfo({required this.pos, required this.name});
}

Future<_CabangInfo?> _findCabangPosition(String cabangName) async {
  try {
    final jsonStr = await rootBundle.loadString('assets/cabangs.json');
    final list = json.decode(jsonStr) as List<dynamic>;
    for (final item in list) {
      final name = (item['name'] as String?)?.toLowerCase() ?? '';
      if (name == cabangName.toLowerCase()) {
        final lat = (item['latitude'] as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return _CabangInfo(pos: LatLng(lat, lng), name: item['name'] as String? ?? cabangName);
        }
      }
    }
  } catch (_) {}
  return null;
}
