import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../datasources/remote/api_service.dart';
import '../datasources/local/hive_cache.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) => SyncRepository());

class SyncRepository {
  static const String _kontersBox = 'konters_cache';
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

  Future<bool> syncGudangs() async {
    try {
      final res = await _api.get(ApiConstants.gudangs);
      final list = (res.data['data'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await HiveCache.saveGudangs(list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncKonters() async {
    try {
      final res = await _api.get(ApiConstants.konters);
      final list = (res.data['data'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _saveKonters(list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> syncAll({bool canSyncKonters = false}) async {
    final futures = [syncDrivers(), syncGudangs()];
    if (canSyncKonters) futures.add(syncKonters());
    final results = await Future.wait(futures);
    return {
      'drivers': results[0],
      'gudangs': results[1],
      'konters': canSyncKonters ? results[2] as bool : true,
    };
  }

  Future<List<Map<String, dynamic>>> getKonters() async {
    final box = await _kontersBoxInstance();
    final list = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      if (key == '__meta__') continue;
      list.add(Map<String, dynamic>.from(box.get(key) as Map));
    }
    return list;
  }

  Future<dynamic> _kontersBoxInstance() async {
    return await HiveCache.openBoxIfNeeded(_kontersBox);
  }

  Future<void> _saveKonters(List<Map<String, dynamic>> konters) async {
    final box = await _kontersBoxInstance();
    for (final k in konters) {
      final id = k['_id']?.toString() ?? k['konter_id']?.toString() ?? '';
      if (id.isNotEmpty) {
        await box.put(id, k);
      }
    }
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
