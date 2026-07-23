import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../data/datasources/local/hive_cache.dart';
import 'cabang_lokasi_service.dart';

class OngkirResult {
  final int min;
  final int perkg;
  final String est;
  final int total;

  OngkirResult({
    required this.min,
    required this.perkg,
    required this.est,
    required this.total,
  });
}

class OngkirService {
  static Map<String, dynamic>? _tariffs;

  static List<String> get availableCities {
    final cities = <String>{};

    // Kota dari cabang aktif
    for (final c in CabangLokasiService.allCabangs) {
      if (c.kota.isNotEmpty) {
        final k = c.kota.trim();
        cities.add(k[0].toUpperCase() + k.substring(1));
      }
    }

    // Kota dari data tarif (asal & tujuan) — mencakup kota yg tidak ada cabangnya
    if (_tariffs != null) {
      for (final t in _tariffs!.values) {
        final m = t as Map;
        final asal = (m['asal'] as String?) ?? '';
        final tujuan = (m['tujuan'] as String?) ?? '';
        if (asal.isNotEmpty) cities.add(asal[0].toUpperCase() + asal.substring(1));
        if (tujuan.isNotEmpty) cities.add(tujuan[0].toUpperCase() + tujuan.substring(1));
      }
    }

    final sorted = cities.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static Future<void> init() async {
    final cached = HiveCache.getTariffs();
    if (cached != null) {
      _tariffs = cached;
      return;
    }
    final json = await rootBundle.loadString('assets/tariff.json');
    _tariffs = Map<String, dynamic>.from(jsonDecode(json) as Map);
  }

  static void updateFromHive() {
    final cached = HiveCache.getTariffs();
    if (cached != null) {
      _tariffs = cached;
    }
    // Cascade refresh ke CabangLokasiService agar daftar kota ikut terbarui
    CabangLokasiService.updateFromHive();
  }

  static String? cabangToKota(String? cabangKota) {
    if (cabangKota == null || cabangKota.isEmpty) return null;
    return cabangKota.toLowerCase();
  }

  static OngkirResult? hitung(
    String asalKota,
    String tujuanKota,
    double berat,
  ) {
    if (_tariffs == null) return null;
    final key = '${asalKota.toLowerCase()}|${tujuanKota.toLowerCase()}';
    final t = _tariffs![key];
    if (t == null) return null;
    // Pakai num + toInt() agar aman baik di native (int) maupun web (double dari JS)
    final min = (t['min'] as num).toInt();
    final perkg = (t['perkg'] as num).toInt();
    final est = t['est'] as String;
    final extra = (berat - 5).clamp(0, double.infinity).ceil();
    final total = min + extra * perkg;
    return OngkirResult(min: min, perkg: perkg, est: est, total: total);
  }
}
