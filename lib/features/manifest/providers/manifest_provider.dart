import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/models/manifest.dart';

/// Filter untuk list manifest
class ManifestFilter {
  final String? status;
  final int page;
  final int limit;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? userId;
  const ManifestFilter({
    this.status,
    this.page = 1,
    this.limit = 20,
    this.startDate,
    this.endDate,
    this.userId,
  });

  ManifestFilter copyWith({
    String? status,
    int? page,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) =>
      ManifestFilter(
        status: status ?? this.status,
        page: page ?? this.page,
        limit: limit ?? this.limit,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        userId: userId ?? this.userId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManifestFilter &&
          status == other.status &&
          page == other.page &&
          limit == other.limit &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          userId == other.userId;

  @override
  int get hashCode =>
      Object.hash(status, page, limit, startDate, endDate, userId);
}

/// Provider untuk list manifest (admin/driver disesuaikan otomatis di backend)
final manifestListProvider =
    FutureProvider.autoDispose.family<ManifestListData, ManifestFilter>(
        (ref, filter) async {
  final params = <String, dynamic>{
    'page': filter.page.toString(),
    'limit': filter.limit.toString(),
  };
  if (filter.status != null) params['status'] = filter.status;
  if (filter.startDate != null)
    params['start_date'] =
        filter.startDate!.toIso8601String().split('T')[0];
  if (filter.endDate != null)
    params['end_date'] = filter.endDate!.toIso8601String().split('T')[0];

  final response = await ApiService().get(ApiConstants.manifests, query: params);
  final data = response.data;
  final list = (data['data'] as List<dynamic>)
      .map((e) => Manifest.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  return ManifestListData(
    manifests: list,
    total: data['total'] as int? ?? 0,
    totalPages: data['totalPages'] as int? ?? 0,
    page: data['page'] as int? ?? 1,
  );
});

class ManifestListData {
  final List<Manifest> manifests;
  final int total;
  final int totalPages;
  final int page;
  const ManifestListData({
    required this.manifests,
    required this.total,
    required this.totalPages,
    required this.page,
  });
}

/// Provider untuk detail manifest + transaksi di dalamnya
final manifestDetailProvider =
    FutureProvider.autoDispose.family<Manifest?, String>((ref, id) async {
  try {
    final response =
        await ApiService().get('${ApiConstants.manifests}/$id');
    return Manifest.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  } catch (_) {
    return null;
  }
});

/// Provider untuk work unit stats (summary bar)
final manifestStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response =
      await ApiService().get('${ApiConstants.manifests}/stats/summary');
  return Map<String, dynamic>.from(response.data['total'] as Map);
});

/// Provider khusus driver — manifest yang belum selesai
final driverManifestProvider =
    FutureProvider.autoDispose<List<Manifest>>((ref) async {
  final response = await ApiService().get(ApiConstants.manifests,
      query: {'status': 'dibuat,dalam_perjalanan'});
  final data = response.data['data'] as List<dynamic>;
  return data
      .map((e) => Manifest.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Provider khusus driver — manifest aktif + detail transaksi di dalamnya
final driverActiveManifestsProvider =
    FutureProvider.autoDispose<List<Manifest>>((ref) async {
  // Step 1: Fetch all active manifests
  final response = await ApiService().get(ApiConstants.manifests,
      query: {'status': 'dibuat,dalam_perjalanan'});
  final data = response.data['data'] as List<dynamic>;
  if (data.isEmpty) return [];

  final manifests = data
      .map((e) => Manifest.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  // Step 2: Fetch detail for each manifest (parallel)
  final details = await Future.wait(
    manifests.map((m) async {
      try {
        final detailResp =
            await ApiService().get('${ApiConstants.manifests}/${m.id}');
        return Manifest.fromJson(
            Map<String, dynamic>.from(detailResp.data as Map));
      } catch (_) {
        return m;
      }
    }),
  );

  return details;
});

/// Provider untuk riwayat manifest driver (selesai, with pagination)
final driverRiwayatManifestsProvider =
    FutureProvider.family<ManifestListData, ManifestFilter>(
        (ref, filter) async {
  final params = <String, dynamic>{
    'page': filter.page.toString(),
    'limit': filter.limit.toString(),
    'status': 'selesai',
    if (filter.startDate != null)
      'start_date': filter.startDate!.toIso8601String().split('T')[0],
    if (filter.endDate != null)
      'end_date': filter.endDate!.toIso8601String().split('T')[0],
  };

  final response = await ApiService().get(ApiConstants.manifests, query: params);
  final data = response.data;
  final list = (data['data'] as List<dynamic>)
      .map((e) => Manifest.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  return ManifestListData(
    manifests: list,
    total: data['total'] as int? ?? 0,
    totalPages: data['totalPages'] as int? ?? 0,
    page: data['page'] as int? ?? 1,
  );
});

/// Refresh support — invalidate all manifest providers
final manifestRefreshProvider = Provider<void>((ref) {
  return;
});

void refreshManifests(WidgetRef ref) {
  ref.invalidate(manifestListProvider);
  ref.invalidate(manifestDetailProvider);
  ref.invalidate(manifestStatsProvider);
  ref.invalidate(driverManifestProvider);
  ref.invalidate(driverActiveManifestsProvider);
  ref.invalidate(driverRiwayatManifestsProvider);
}
