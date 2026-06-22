import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/models/manifest.dart';

/// Filter untuk list manifest
class ManifestFilter {
  final String? status;
  final int page;
  final int limit;
  const ManifestFilter({this.status, this.page = 1, this.limit = 20});

  ManifestFilter copyWith({String? status, int? page, int? limit}) =>
      ManifestFilter(
        status: status ?? this.status,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );
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
    FutureProvider.autoDispose.family<ManifestListData, ManifestFilter>(
        (ref, filter) async {
  final params = <String, dynamic>{
    'page': filter.page.toString(),
    'limit': filter.limit.toString(),
    'status': 'selesai',
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
