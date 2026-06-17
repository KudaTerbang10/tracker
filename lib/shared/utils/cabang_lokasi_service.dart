import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import '../../data/datasources/local/hive_cache.dart';
import '../../core/constants/api_constants.dart';

class CabangLokasi {
  final String cabangId;
  final String kode;
  final String name;
  final String address;
  final String phone;
  final String kota;
  final double? latitude;
  final double? longitude;

  CabangLokasi({
    required this.cabangId,
    required this.kode,
    required this.name,
    required this.address,
    required this.phone,
    required this.kota,
    this.latitude,
    this.longitude,
  });

  factory CabangLokasi.fromMap(Map<String, dynamic> json) {
    return CabangLokasi(
      cabangId: json['cabang_id'] as String? ?? json['_id'] as String,
      kode: json['kode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      kota: json['kota'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  bool get hasCoords => latitude != null && longitude != null;
}

class CabangTerdekat {
  final CabangLokasi cabang;
  final double jarakKm;

  CabangTerdekat({required this.cabang, required this.jarakKm});

  String get jarakLabel {
    if (jarakKm < 1) return '${(jarakKm * 1000).toStringAsFixed(0)} m';
    return '${jarakKm.toStringAsFixed(2)} km';
  }
}

class CabangLokasiService {
  static List<CabangLokasi>? _cabangs;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // 1. Hive cache dulu (instan, zero network)
    final cached = HiveCache.getCabangs();
    if (cached.isNotEmpty) {
      _cabangs = cached.map((e) => CabangLokasi.fromMap(e)).toList();
    } else {
      // 2. Fallback ke bundled JSON
      final json = await rootBundle.loadString('assets/cabangs.json');
      final list = jsonDecode(json) as List<dynamic>;
      _cabangs = list
          .map((e) => CabangLokasi.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    _initialized = true;

    // 3. Refresh dari API publik di background (tidak blocking)
    _refreshFromApi();
  }

  static Future<void> _refreshFromApi() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get(ApiConstants.cabangs);
      final list = (res.data['data'] as List<dynamic>)
          .map((e) => CabangLokasi.fromMap(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        _cabangs = list;
      }
    } catch (_) {
      // Abaikan, data Hive/JSON sudah cukup
    }
  }

  static void updateFromHive() {
    final cached = HiveCache.getCabangs();
    if (cached.isNotEmpty) {
      _cabangs = cached.map((e) => CabangLokasi.fromMap(e)).toList();
    }
  }

  static List<CabangLokasi> get allCabangs =>
      List.unmodifiable(_cabangs ?? []);

  /// Haversine formula
  static double _hitungJarak(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // radius bumi dalam km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * pi / 180;

  /// Cari cabang terdekat dalam radius tertentu dari posisi user
  static List<CabangTerdekat> cariTerdekat({
    required double userLat,
    required double userLng,
    double radiusKm = 20.0,
  }) {
    if (_cabangs == null) return [];

    final hasil = <CabangTerdekat>[];

    for (final c in _cabangs!) {
      if (!c.hasCoords) continue;
      final jarak = _hitungJarak(userLat, userLng, c.latitude!, c.longitude!);
      if (jarak <= radiusKm) {
        hasil.add(CabangTerdekat(cabang: c, jarakKm: jarak));
      }
    }

    hasil.sort((a, b) => a.jarakKm.compareTo(b.jarakKm));
    return hasil;
  }
}
