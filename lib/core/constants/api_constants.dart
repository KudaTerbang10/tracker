import 'package:flutter/foundation.dart';

class ApiConstants {
  /// Override manual: isi dengan 'http://192.168.1.x:5000/api' jika pakai device fisik
  static String customBaseUrl = '';

  /// Otomatis pilih URL sesuai platform.
  /// Bisa dioverride dengan mengisi [customBaseUrl] sebelumnya.
  static String get baseUrl {
    if (customBaseUrl.isNotEmpty) return customBaseUrl;
    if (kIsWeb) return 'http://localhost:5000/api';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:5000/api';
    return 'http://localhost:5000/api';
  }

  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String track = '/track';
  static const String transactions = '/transactions';
  static const String batchStatus = '/transactions/batch-status';
  static const String drivers = '/drivers';
  static const String users = '/users';
  static const String cabangs = '/cabangs';
  static const String analyticsTraffic = '/analytics/traffic';
  static const String analyticsCustomers = '/analytics/customers-top';
  static const String analyticsSummary = '/analytics/summary';
  static const String analyticsPerCabang = '/analytics/per-cabang';
  static const String analyticsDrivers = '/analytics/drivers';
  static const String health = '/health';
  static const String tariffs = '/tariffs';
}

class StatusList {
  static const List<String> all = [
    'diterima_cabang',
    'keluar_cabang',
    'proses_kirim',
    'diterima',
  ];

  static const Map<String, String> labels = {
    'diterima_cabang': 'Diterima Cabang',
    'keluar_cabang': 'Keluar Cabang',
    'proses_kirim': 'Proses Kirim',
    'diterima': 'Diterima',
  };

  static String label(String status) => labels[status] ?? status;
}
