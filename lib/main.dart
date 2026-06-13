import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'data/datasources/local/hive_cache.dart';
import 'data/repositories/sync_repository.dart';
import 'shared/utils/ongkir_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await HiveCache.init();
  await OngkirService.init();
  await _bootstrapSync();
  runApp(const ProviderScope(child: TrackerApp()));
}

Future<void> _bootstrapSync() async {
  final lastSynced = HiveCache.getLastSynced();
  final now = DateTime.now();
  final needSync = lastSynced == null || now.difference(lastSynced).inHours >= 24;

  if (!needSync) return;
  final sync = SyncRepository();
  await Future.wait([
    if (HiveCache.getDrivers().isEmpty) sync.syncDrivers(),
    sync.syncCabangs(),
    sync.syncTariffs(),
  ]);
  OngkirService.updateFromHive();
}
