import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'data/datasources/local/hive_cache.dart';
import 'data/repositories/sync_repository.dart';
import 'shared/utils/ongkir_service.dart';
import 'shared/utils/cabang_lokasi_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await HiveCache.init();
  await OngkirService.init();
  await CabangLokasiService.init();
  await _bootstrapSync();
  runApp(const ProviderScope(child: TrackerApp()));
}

Future<void> _bootstrapSync() async {
  final sync = SyncRepository();
  // Cabang selalu di-sync agar perubahan di manajemen cabang (mis. "Jakarta Pusat"
  // -> "Jakarta") langsung masuk ke HP, bukan cuma saat full sync 24 jam.
  final futures = <Future>[
    if (HiveCache.getDrivers().isEmpty) sync.syncDrivers(),
    sync.syncCabangs(),
  ];
  await Future.wait(futures);

  // Refresh cabang dulu agar OngkirService.availableCities pakai data terbaru
  CabangLokasiService.updateFromHive();

  // Tarif selalu sync via endpoint publik — tarif terbaru dari admin
  // akan tersedia untuk user public tanpa perlu login.
  final tariffsOk = await sync.syncTariffsPublic();
  if (tariffsOk) OngkirService.updateFromHive();
}
