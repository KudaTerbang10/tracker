import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'data/datasources/local/hive_cache.dart';
import 'data/repositories/sync_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await HiveCache.init();
  await HiveCache.openBoxIfNeeded('konters_cache');
  await _bootstrapSync();
  runApp(const ProviderScope(child: TrackerApp()));
}

Future<void> _bootstrapSync() async {
  final lastSynced = HiveCache.getLastSynced();
  final now = DateTime.now();
  final needSync = lastSynced == null || now.difference(lastSynced).inHours >= 24;

  if (!needSync) return;
  if (HiveCache.getDrivers().isEmpty || HiveCache.getGudangs().isEmpty) {
    final sync = SyncRepository();
    await Future.wait([sync.syncDrivers(), sync.syncGudangs(), sync.syncKonters()]);
  }
}
