import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';

enum ScanType { datang, keluar, diterima }

enum TujuanType { cabang, penerima }

class ScanItem {
  final String noResi;
  final Transaction transaction;
  final bool isValid;
  final String? errorMessage;

  ScanItem({
    required this.noResi,
    required this.transaction,
    this.isValid = true,
    this.errorMessage,
  });
}

class ScanKeluarState {
  final List<ScanItem> scannedItems;
  final String? driverUserId;
  final String? driverName;
  final String? driverPhone;
  final TujuanType tujuanType;
  final String? cabangTujuanId;
  final String? cabangTujuanNama;

  ScanKeluarState({
    this.scannedItems = const [],
    this.driverUserId,
    this.driverName,
    this.driverPhone,
    this.tujuanType = TujuanType.cabang,
    this.cabangTujuanId,
    this.cabangTujuanNama,
  });

  ScanKeluarState copyWith({
    List<ScanItem>? scannedItems,
    String? driverUserId,
    String? driverName,
    String? driverPhone,
    TujuanType? tujuanType,
    String? cabangTujuanId,
    String? cabangTujuanNama,
  }) => ScanKeluarState(
    scannedItems: scannedItems ?? this.scannedItems,
    driverUserId: driverUserId ?? this.driverUserId,
    driverName: driverName ?? this.driverName,
    driverPhone: driverPhone ?? this.driverPhone,
    tujuanType: tujuanType ?? this.tujuanType,
    cabangTujuanId: cabangTujuanId ?? this.cabangTujuanId,
    cabangTujuanNama: cabangTujuanNama ?? this.cabangTujuanNama,
  );

  int get validCount => scannedItems.where((i) => i.isValid).length;
}

final scanDatangProvider = StateNotifierProvider<ScanDatangNotifier, List<ScanItem>>((ref) => ScanDatangNotifier());
final scanKeluarProvider = StateNotifierProvider<ScanKeluarNotifier, ScanKeluarState>((ref) => ScanKeluarNotifier());

class ScanDatangNotifier extends StateNotifier<List<ScanItem>> {
  ScanDatangNotifier() : super([]);

  void addItem(ScanItem item) {
    final exists = state.any((i) => i.noResi == item.noResi);
    if (!exists) {
      state = [...state, item];
    }
  }

  void removeItem(String noResi) {
    state = state.where((i) => i.noResi != noResi).toList();
  }

  void clear() => state = [];
}

class ScanKeluarNotifier extends StateNotifier<ScanKeluarState> {
  ScanKeluarNotifier() : super(ScanKeluarState());

  void addItem(ScanItem item) {
    if (!item.isValid) {
      state = state.copyWith(scannedItems: [...state.scannedItems, item]);
      return;
    }
    final exists = state.scannedItems.any((i) => i.noResi == item.noResi);
    if (!exists) {
      state = state.copyWith(scannedItems: [...state.scannedItems, item]);
    }
  }

  void removeItem(String noResi) {
    final newList = state.scannedItems.where((i) => i.noResi != noResi).toList();
    final stillHasValid = newList.any((i) => i.isValid);
    state = state.copyWith(
      scannedItems: newList,
      driverUserId: stillHasValid ? state.driverUserId : null,
      driverName: stillHasValid ? state.driverName : null,
      driverPhone: stillHasValid ? state.driverPhone : null,
      cabangTujuanId: stillHasValid ? state.cabangTujuanId : null,
      cabangTujuanNama: stillHasValid ? state.cabangTujuanNama : null,
    );
  }

  void setDriver(String userId, String name, String phone) {
    state = state.copyWith(driverUserId: userId, driverName: name, driverPhone: phone);
  }

  void setDriverManual(String name, String phone) {
    state = state.copyWith(driverUserId: null, driverName: name, driverPhone: phone);
  }

  void setTujuanType(TujuanType type) {
    state = state.copyWith(tujuanType: type);
  }

  void setCabangTujuan(String id, String name) {
    state = state.copyWith(cabangTujuanId: id, cabangTujuanNama: name);
  }

  void setCabangTujuanManual(String name) {
    state = state.copyWith(cabangTujuanId: null, cabangTujuanNama: name);
  }

  void clear() => state = ScanKeluarState();
}
