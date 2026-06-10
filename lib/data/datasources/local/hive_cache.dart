import 'package:hive_flutter/hive_flutter.dart';

class HiveCache {
  static const String _driverBox = 'drivers_cache';
  static const String _cabangBox = 'cabangs_cache';
  static const String _metaKey = '__meta__';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_driverBox);
    await Hive.openBox(_cabangBox);
  }

  static Future<Box> openBoxIfNeeded(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box(name);
    return await Hive.openBox(name);
  }

  static Box _driver() => Hive.box(_driverBox);
  static Box _cabang() => Hive.box(_cabangBox);

  static Future<void> saveDrivers(List<Map<String, dynamic>> drivers) async {
    final box = _driver();
    await box.clear();
    for (final d in drivers) {
      await box.put(d['user_id'].toString(), d);
    }
    await box.put(_metaKey, {'last_synced': DateTime.now().toIso8601String()});
  }

  static List<Map<String, dynamic>> getDrivers({String? query}) {
    final box = _driver();
    final list = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      if (key == _metaKey) continue;
      final data = Map<String, dynamic>.from(box.get(key) as Map);
      if (query != null) {
        final name = (data['name'] as String).toLowerCase();
        final phone = (data['phone'] as String).toLowerCase();
        if (!name.contains(query.toLowerCase()) && !phone.contains(query.toLowerCase())) {
          continue;
        }
      }
      list.add(data);
    }
    return list;
  }

  static Future<void> saveCabangs(List<Map<String, dynamic>> cabangs) async {
    final box = _cabang();
    await box.clear();
    for (final c in cabangs) {
      await box.put(c['cabang_id'].toString(), c);
    }
    await box.put(_metaKey, {'last_synced': DateTime.now().toIso8601String()});
  }

  static List<Map<String, dynamic>> getCabangs({String? query}) {
    final box = _cabang();
    final list = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      if (key == _metaKey) continue;
      final data = Map<String, dynamic>.from(box.get(key) as Map);
      if (query != null) {
        final name = (data['name'] as String).toLowerCase();
        final kode = (data['kode'] as String).toLowerCase();
        if (!name.contains(query.toLowerCase()) && !kode.contains(query.toLowerCase())) {
          continue;
        }
      }
      list.add(data);
    }
    return list;
  }

  static DateTime? getLastSynced() {
    final box = _driver();
    final meta = box.get(_metaKey);
    if (meta == null) return null;
    return DateTime.tryParse((meta as Map)['last_synced'] as String);
  }

}
