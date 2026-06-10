import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../datasources/remote/api_service.dart';
import '../models/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) => TransactionRepository());

class TransactionRepository {
  final _api = ApiService();

  Future<Transaction> create({
    required Map<String, dynamic> pengirim,
    required Map<String, dynamic> penerima,
    required Map<String, dynamic> paket,
    String? catatan,
  }) async {
    final res = await _api.post(ApiConstants.transactions, data: {
      'pengirim': pengirim,
      'penerima': penerima,
      'paket': paket,
      'catatan': catatan,
    });
    return Transaction.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> batchUpdateStatus({
    required List<String> noResiList,
    required String statusBaru,
    String? driverUserId,
    String? tipeTujuan,
    String? cabangTujuanId,
    String? namaDriverManual,
    String? cabangNamaManual,
    String? catatan,
    String? namaPenerima,
  }) async {
    final res = await _api.post(ApiConstants.batchStatus, data: {
      'no_resi_list': noResiList,
      'status_baru': statusBaru,
      if (driverUserId != null && driverUserId.isNotEmpty) 'driver_user_id': driverUserId,
      if (tipeTujuan != null) 'tipe_tujuan': tipeTujuan,
      if (cabangTujuanId != null && cabangTujuanId.isNotEmpty) 'cabang_tujuan_id': cabangTujuanId,
      if (namaDriverManual != null && namaDriverManual.isNotEmpty) 'nama_driver_manual': namaDriverManual,
      if (cabangNamaManual != null && cabangNamaManual.isNotEmpty) 'cabang_nama_manual': cabangNamaManual,
      if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
      if (namaPenerima != null && namaPenerima.isNotEmpty) 'nama_penerima': namaPenerima,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _api.delete('${ApiConstants.transactions}/$id');
  }

  Future<Map<String, dynamic>> getList({String? status, String? kodeGerai, String? tab, int page = 1, int limit = 20}) async {
    final res = await _api.get(ApiConstants.transactions, query: {
      if (status != null) 'status': status,
      if (kodeGerai != null) 'kode_gerai': kodeGerai,
      if (tab != null) 'tab': tab,
      'page': page,
      'limit': limit,
    });
    final data = res.data as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>)
        .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return {
      'data': list,
      'total': data['total'],
      'page': data['page'],
      'totalPages': data['totalPages'],
    };
  }
}
