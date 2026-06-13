import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../datasources/remote/api_service.dart';
import '../datasources/local/hive_cache.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) => SyncRepository());

class SyncRepository {
  final _api = ApiService();

  Future<bool> syncDrivers() async {
    try {
      final res = await _api.get(ApiConstants.drivers);
      final list = (res.data['data'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await HiveCache.saveDrivers(list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncCabangs() async {
    try {
      final res = await _api.get(ApiConstants.cabangs);
      final list = (res.data['data'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await HiveCache.saveCabangs(list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncTariffs() async {
    try {
      final res = await _api.get(ApiConstants.tariffs);
      final list = (res.data['data'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await HiveCache.saveTariffs(list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> syncAll() async {
    final results = await Future.wait([
      syncDrivers(),
      syncCabangs(),
      syncTariffs(),
    ]);
    return {
      'drivers': results[0],
      'cabangs': results[1],
      'tariffs': results[2],
    };
  }

  Future<bool> checkConnection() async {
    try {
      await _api.get(ApiConstants.health);
      return true;
    } catch (_) {
      return false;
    }
  }
}
