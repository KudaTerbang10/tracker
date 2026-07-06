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
    Map<String, dynamic>? lokasiPenerima,
    String? catatan,
    String? jenisPembayaran,
    int? tempoHari,
  }) async {
    final res = await _api.post(ApiConstants.transactions, data: {
      'pengirim': pengirim,
      'penerima': penerima,
      'paket': paket,
      'lokasi_penerima': lokasiPenerima,
      'catatan': catatan,
      if (jenisPembayaran != null) 'jenis_pembayaran': jenisPembayaran,
      if (tempoHari != null) 'tempo_hari': tempoHari,
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

  Future<Transaction> laporkanMasalah({
    required String id,
    required String jenis,
    required String catatan,
  }) async {
    final res = await _api.post('${ApiConstants.transactions}/$id/laporkan-masalah', data: {
      'jenis': jenis,
      'catatan': catatan,
    });
    return Transaction.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Transaction> tandaiSelesai(String id) async {
    final res = await _api.put('${ApiConstants.transactions}/$id/tandai-selesai');
    return Transaction.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.delete('${ApiConstants.transactions}/$id');
  }

  Future<Map<String, dynamic>> getRecentContacts(String cabangId) async {
    final response = await _api.get(
      ApiConstants.recentContacts,
      query: {'cabang_id': cabangId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getList({String? status, String? search, String? kodeGerai, String? tab, int page = 1, int limit = 20, DateTime? startDate, DateTime? endDate}) async {
    final res = await _api.get(ApiConstants.transactions, query: {
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (kodeGerai != null) 'kode_gerai': kodeGerai,
      if (tab != null) 'tab': tab,
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
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

  Future<List<Transaction>> getUnpaidCOD() async {
    final res = await _api.get(ApiConstants.transactions, query: {
      'jenis_pembayaran': 'cod',
      'status_pembayaran': 'unpaid',
      'limit': '1000',
    });
    final data = res.data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>)
        .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Transaction>> getUnpaidTempo() async {
    final res = await _api.get(ApiConstants.transactions, query: {
      'jenis_pembayaran': 'tempo',
      'status_pembayaran': 'unpaid',
      'limit': '1000',
    });
    final data = res.data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>)
        .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Transaction> confirmPayment(String id) async {
    final res = await _api.put('${ApiConstants.transactions}/$id/konfirmasi-pembayaran');
    return Transaction.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> verifyLocation({
    required String id,
    required double lat,
    required double lng,
  }) async {
    final res = await _api.post('${ApiConstants.transactions}/$id/verify-location', data: {
      'lat': lat,
      'lng': lng,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Transaction>> getPaymentByMonth({required String jenisPembayaran, required int month, required int year, String? statusPembayaran, String? driverUserId}) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    final query = <String, dynamic>{
      'jenis_pembayaran': jenisPembayaran,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'limit': '2000',
    };
    if (statusPembayaran != null && statusPembayaran.isNotEmpty) query['status_pembayaran'] = statusPembayaran;
    if (driverUserId != null && driverUserId.isNotEmpty) query['driver_user_id'] = driverUserId;
    final res = await _api.get(ApiConstants.transactions, query: query);
    final data = res.data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>)
        .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPerCabangReport({required int month, required int year}) async {
    final res = await _api.get(ApiConstants.analyticsPerCabang, query: {
      'month': month.toString(),
      'year': year.toString(),
    });
    final data = res.data['data'] as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getRoutesTop({required int month, required int year}) async {
    final res = await _api.get(ApiConstants.analyticsRoutesTop, query: {
      'month': month.toString(),
      'year': year.toString(),
    });
    final data = res.data['data'] as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getDriverReport({required int month, required int year}) async {
    final res = await _api.get(ApiConstants.analyticsDrivers, query: {
      'month': month.toString(),
      'year': year.toString(),
    });
    final data = res.data['data'] as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getDriverPerformance({required int month, required int year}) async {
    final res = await _api.get(ApiConstants.analyticsDriverPerformance, query: {
      'month': month.toString(),
      'year': year.toString(),
    });
    return Map<String, dynamic>.from(res.data);
  }
}
