import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class OngkirResult {
  final int min;
  final int perkg;
  final String est;
  final int total;

  OngkirResult({required this.min, required this.perkg, required this.est, required this.total});
}

class OngkirService {
  static Map<String, dynamic>? _tariffs;

  static const List<String> availableCities = [
    'Bandung', 'Bekasi', 'Bogor', 'Bojonegoro', 'Cilacap', 'Cimahi',
    'Cirebon', 'Denpasar', 'Jakarta', 'Jember', 'Kediri', 'Kudus',
    'Kuningan', 'Madiun', 'Magelang', 'Malang', 'Mojokerto', 'Nganjuk',
    'Ngawi', 'Parakan', 'Pare', 'Pekalongan', 'Probolinggo', 'Purwokerto',
    'Semarang', 'Sidoarjo', 'Solo', 'Sragen', 'Surabaya', 'Tangerang',
    'Tasikmalaya', 'Tegal', 'Temanggung', 'Tulung Agung', 'Ungaran',
    'Wonosobo', 'Yogyakarta',
  ];

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
    'Sukoharjo': 'solo',
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
    final json = await rootBundle.loadString('assets/tariff.json');
    _tariffs = jsonDecode(json) as Map<String, dynamic>;
  }

  static String? cabangToKota(String? cabangNama) {
    if (cabangNama == null) return null;
    return _cabangToKota[cabangNama];
  }

  static OngkirResult? hitung(String asalKota, String tujuanKota, double berat) {
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
