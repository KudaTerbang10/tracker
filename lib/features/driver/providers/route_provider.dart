import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/utils/cabang_lokasi_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../utils/route_optimizer.dart';

final routeProvider = FutureProvider.autoDispose<RouteData?>((ref) async {
  try {
    await CabangLokasiService.init();
    final user = ref.watch(authProvider).user;
    if (user == null) return null;

    // Data transaksi yang masih dalam proses kirim
    final result = await ref.read(transactionRepositoryProvider).getList(
      status: 'proses_kirim',
      limit: 999,
    );
    final transactions = result['data'] as List<Transaction>;

    // Siapkan direktori cabang: dari memory cache, fallback ke file
    Map<String, LatLng> cabangMap = {};
    if (CabangLokasiService.allCabangs.isNotEmpty) {
      for (final c in CabangLokasiService.allCabangs) {
        if (c.latitude != null && c.longitude != null) {
          final key = c.name.toLowerCase().trim();
          cabangMap[key] = LatLng(c.latitude!, c.longitude!);
        }
      }
    }
    if (cabangMap.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('assets/cabangs.json');
        final list = json.decode(jsonStr) as List<dynamic>;
        for (final item in list) {
          final name = (item['name'] as String?)?.trim().toLowerCase() ?? '';
          final lokasi = item['lokasi'] as Map<String, dynamic>?;
          if (lokasi != null && lokasi['type'] == 'Point') {
            final coords = lokasi['coordinates'] as List<dynamic>?;
            if (coords != null && coords.length == 2) {
              cabangMap[name] = LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
            }
          }
        }
      } catch (_) {}
    }

    LatLng? origin;
    String originName = 'Lokasi Awal';
    bool originIsCabang = true;
    final stops = <RouteStop>[];
    final cabangStopMap = <String, RouteStop>{};

    for (final tx in transactions) {
      if (tx.driverUserId != user.id) continue;

      final tipeTujuan = tx.tujuanSelanjutnya?['tipe'] as String?;
      final namaTujuan = (tx.tujuanSelanjutnya?['nama'] as String?)?.trim().toLowerCase() ?? '';

      if (tipeTujuan == 'penerima') {
        if (tx.penerimaLatitude == null || tx.penerimaLongitude == null) continue;
        stops.add(RouteStop(
          transaction: tx,
          coordinates: LatLng(tx.penerimaLatitude!, tx.penerimaLongitude!),
        ));
      } else if (tipeTujuan == 'cabang' && namaTujuan.isNotEmpty) {
        final coord = cabangMap[namaTujuan];
        if (coord == null) continue;
        if (cabangStopMap.containsKey(namaTujuan)) {
          cabangStopMap[namaTujuan]!.addTransaction(tx);
        } else {
          final stop = RouteStop(transaction: tx, coordinates: coord, isCabang: true);
          cabangStopMap[namaTujuan] = stop;
          stops.add(stop);
        }
      }
    }

    if (stops.isEmpty) return null;

    // Cek apakah driver sudah pernah menyelesaikan pengiriman sebelumnya
    // Jika ya, pakai titik terakhir sebagai origin agar rute lanjut dari sana
    try {
      final deliveredResult = await ref.read(transactionRepositoryProvider).getList(
        tab: 'history',
        status: 'diterima',
        limit: 1,
      );
      final deliveredList = deliveredResult['data'] as List<Transaction>;
      if (deliveredList.isNotEmpty) {
        final last = deliveredList.first;
        if (last.penerimaLatitude != null && last.penerimaLongitude != null) {
          origin = LatLng(last.penerimaLatitude!, last.penerimaLongitude!);
          originName = last.penerimaName;
          originIsCabang = false;
        }
      }
    } catch (_) {
      // Abaikan, lanjut cari dari tracking_logs
    }

    // Jika belum ada kiriman selesai, cari cabang asal dari tracking_logs
    if (origin == null) {
      for (final tx in transactions) {
        if (tx.driverUserId != user.id) continue;
        for (final log in tx.trackingLogs.reversed) {
          if (log.status == 'keluar_cabang') {
            final namaCabang = log.lokasiName.trim().toLowerCase();
            if (namaCabang.isNotEmpty && cabangMap.containsKey(namaCabang)) {
              origin = cabangMap[namaCabang];
              originName = log.lokasiName;
              break;
            }
          }
        }
        if (origin != null) break;
      }
    }

    // Fallback: pakai stop pertama sebagai origin
    if (origin == null && stops.isNotEmpty) {
      origin = stops.first.coordinates;
    }

    final ordered = nearestNeighbor(origin!, stops);

    var total = haversine(origin!, ordered.first.coordinates);
    for (var i = 1; i < ordered.length; i++) {
      total += haversine(ordered[i - 1].coordinates, ordered[i].coordinates);
    }

    return RouteData(
      start: origin!,
      startName: originName,
      startIsCabang: originIsCabang,
      orderedStops: ordered,
      totalDistanceKm: total,
    );
  } catch (_) {
    return null;
  }
});
