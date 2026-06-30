import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../data/datasources/local/hive_cache.dart';

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
  static List<String>? _cachedCities;

  static List<String> get availableCities {
    if (_cachedCities != null && _cachedCities!.isNotEmpty) return _cachedCities!;
    if (_tariffs == null) return [];
    final cities = <String>{};
    for (final t in _tariffs!.values) {
      final m = t as Map;
      final asal = (m['asal'] as String?) ?? '';
      final tujuan = (m['tujuan'] as String?) ?? '';
      if (asal.isNotEmpty) cities.add(asal[0].toUpperCase() + asal.substring(1));
      if (tujuan.isNotEmpty) cities.add(tujuan[0].toUpperCase() + tujuan.substring(1));
    }
    final sorted = cities.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _cachedCities = sorted;
    return sorted;
  }

  static const _cabangToKota = {
    'Tangerang Selatan': 'tangerang',
    'Bekasi': 'bekasi',
    'Bogor': 'bogor',
    'Bandung': 'bandung',
    'Tasikmalaya': 'tasikmalaya',
    'Cirebon': 'cirebon',
    'Tegal': 'tegal',
    'Pekalongan': 'pekalongan',
    'Purwokerto': 'purwokerto',
    'Semarang': 'semarang',
    'Kudus': 'kudus',
    'Ungaran': 'ungaran',
    'Magelang': 'magelang',
    'Solo': 'solo',
    'Yogyakarta': 'yogyakarta',
    'Surabaya': 'surabaya',
    'Sidoarjo': 'sidoarjo',
    'Jember': 'jember',
    'Kediri': 'kediri',
    'Malang': 'malang',
    'Denpasar': 'denpasar',
    'Jakarta Barat': 'jakarta',
    'Jakarta Pusat': 'jakarta',
    'Jakarta Timur': 'jakarta',
    'Jakarta Utara': 'jakarta',
  };

  static Future<void> init() async {
    final cached = HiveCache.getTariffs();
    if (cached != null) {
      _tariffs = cached;
      _cachedCities = null;
      return;
    }
    final json = await rootBundle.loadString('assets/tariff.json');
    _tariffs = jsonDecode(json) as Map<String, dynamic>;
    _cachedCities = null;
  }

  static void updateFromHive() {
    final cached = HiveCache.getTariffs();
    if (cached != null) {
      _tariffs = cached;
      _cachedCities = null;
    }
  }

  static String? cabangToKota(String? cabangNama) {
    if (cabangNama == null) return null;
    final mapped = _cabangToKota[cabangNama];
    if (mapped != null) return mapped;
    return cabangNama.toLowerCase();
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
    final min = t['min'] as int;
    final perkg = t['perkg'] as int;
    final est = t['est'] as String;
    final extra = (berat - 5).clamp(0, double.infinity).ceil();
    final total = min + extra * perkg;
    return OngkirResult(min: min, perkg: perkg, est: est, total: total);
  }
}
