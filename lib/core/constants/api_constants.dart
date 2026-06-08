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
  static const String gudangs = '/gudangs';
  static const String users = '/users';
  static const String konters = '/konters';
  static const String analyticsTraffic = '/analytics/traffic';
  static const String analyticsCustomers = '/analytics/customers-top';
  static const String analyticsSummary = '/analytics/summary';
  static const String health = '/health';
}

class StatusList {
  static const List<String> all = [
    'diterima_konter',
    'keluar_konter',
    'diterima_gudang',
    'keluar_gudang',
    'proses_kirim',
    'diterima',
  ];

  static const Map<String, String> labels = {
    'diterima_konter': 'Diterima di Cabang',
    'keluar_konter': 'Keluar Cabang',
    'diterima_gudang': 'Diterima di Cabang',
    'keluar_gudang': 'Keluar Cabang',
    'proses_kirim': 'Proses Kirim',
    'diterima': 'Diterima',
  };

  static String label(String status) => labels[status] ?? status;
}
