import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/manifest.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../manifest/providers/manifest_provider.dart' as manifest_prov;
import '../providers/route_provider.dart';
import '../widgets/driver_route_map.dart';
import '../../../shared/utils/cabang_lokasi_service.dart';

final kirimProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref
      .read(transactionRepositoryProvider)
      .getList(status: 'proses_kirim', limit: 999);
});

// Work unit summary untuk driver
final driverWorkUnitProvider = FutureProvider.autoDispose<int>((ref) async {
  final response = await ApiService().get('${ApiConstants.manifests}/stats/summary');
  final data = response.data['total'] as Map<String, dynamic>;
  return (data['work_unit'] as num?)?.toInt() ?? 0;
});

class DriverTabScreen extends ConsumerStatefulWidget {
  const DriverTabScreen({super.key});
  @override
  ConsumerState<DriverTabScreen> createState() => _DriverTabScreenState();
}

class _DriverTabScreenState extends ConsumerState<DriverTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime? _startDate;
  DateTime? _endDate;

  // infinite scroll riwayat
  final _riwayatItems = <Manifest>[];
  int _riwayatPage = 1;
  bool _hasMore = true;
  final _riwayatScrollC = ScrollController();
  bool _riwayatLoading = false;

  // Horizontal scroll
  final _manifestScrollCtrl = ScrollController();
  double _manifestScrollPos = 0;

  @override
  void initState() {
    super.initState();
    _requestLocationIfNeeded();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || !mounted) return;
      if (_tabController.index == 0) {
        ref.invalidate(manifest_prov.driverActiveManifestsProvider);
        ref.invalidate(manifest_prov.manifestStatsProvider);
      } else if (_tabController.index == 1) {
        _resetRiwayat();
      }
    });
    _riwayatScrollC.addListener(_onRiwayatScroll);
    _manifestScrollCtrl.addListener(() {
      if (!mounted) return;
      if (_manifestScrollCtrl.hasClients) {
        setState(() {
          _manifestScrollPos = _manifestScrollCtrl.position.pixels;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _riwayatScrollC.dispose();
    _manifestScrollCtrl.dispose();
    super.dispose();
  }

  void _resetRiwayat() {
    final uid = ref.read(authProvider).user?.id;
    setState(() {
      _riwayatPage = 1;
      _riwayatItems.clear();
      _hasMore = true;
      _riwayatLoading = false;
    });
    ref.invalidate(manifest_prov.driverRiwayatManifestsProvider(
      manifest_prov.ManifestFilter(
        status: 'selesai',
        page: 1,
        limit: 20,
        startDate: _startDate,
        endDate: _endDate,
        userId: uid,
      ),
    ));
  }

  void _onRiwayatScroll() {
    if (!_riwayatScrollC.hasClients || !_hasMore || _riwayatLoading) return;
    final max = _riwayatScrollC.position.maxScrollExtent;
    final cur = _riwayatScrollC.position.pixels;
    if (cur >= max - 200) {
      _loadMoreRiwayat();
    }
  }

  void _loadMoreRiwayat() {
    final uid = ref.read(authProvider).user?.id;
    setState(() => _riwayatLoading = true);
    ref.invalidate(manifest_prov.driverRiwayatManifestsProvider(
      manifest_prov.ManifestFilter(
        status: 'selesai',
        page: _riwayatPage + 1,
        limit: 20,
        startDate: _startDate,
        endDate: _endDate,
        userId: uid,
      ),
    ));
  }

  Future<void> _navigateToMaps(Transaction tx) async {
    try {
      final driverLocation = await _getDriverLocation();
      final destLat = tx.penerimaLatitude;
      final destLng = tx.penerimaLongitude;

      if (destLat == null || destLng == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lokasi tujuan tidak tersedia'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (driverLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mendapatkan lokasi driver'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=${driverLocation.latitude.toString()},${driverLocation.longitude.toString()}&destination=${destLat.toString()},${destLng.toString()}&travelmode=driving',
      );

      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka Google Maps: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _navigateToCabang(String cabangNama, {double? lat, double? lng}) async {
    try {
      final driverLocation = await _getDriverLocation();
      String url;
      if (lat != null && lng != null) {
        if (driverLocation != null) {
          url = 'https://www.google.com/maps/dir/?api=1&origin=${driverLocation.latitude},${driverLocation.longitude}&destination=$lat,$lng&travelmode=driving';
        } else {
          url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        }
      } else {
        if (driverLocation != null) {
          url = 'https://www.google.com/maps/dir/?api=1&origin=${driverLocation.latitude},${driverLocation.longitude}&destination=${Uri.encodeComponent('$cabangNama, Indonesia')}&travelmode=driving';
        } else {
          url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$cabangNama, Indonesia')}';
        }
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Haversine — jarak dalam meter antara dua koordinat
  double _distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000;
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<Position?> _getDriverLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return position;
    } catch (e) {
      return null;
    }
  }

  Future<void> _requestLocationIfNeeded() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifestsAsync = ref.watch(manifest_prov.driverActiveManifestsProvider);
    final manifestsData = manifestsAsync.valueOrNull ?? <Manifest>[];
    final manifestCount = manifestsData.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Perlu Dikirim'),
                  if (manifestCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$manifestCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildKirimTab(), _buildRiwayatTab()],
      ),
    );
  }

  Map<String, dynamic>? _tujuanUntukDriver(Transaction tx, String? userId) {
    if (userId == null) return null;
    for (final log in tx.trackingLogs) {
      if (log.driverDitugaskan?['user_id']?.toString() == userId) {
        return log.tujuan;
      }
    }
    return null;
  }

  /// Sortir transaksi: yg punya koordinat & terdekat dari cabang asal ke penerima jadi paling atas
  List<Transaction> _sortTransaksiByDistance(List<Transaction> txs, double cabangLat, double cabangLng) {
    final sorted = List<Transaction>.from(txs);
    sorted.sort((a, b) {
      final aLat = a.penerimaLatitude;
      final aLng = a.penerimaLongitude;
      final bLat = b.penerimaLatitude;
      final bLng = b.penerimaLongitude;

      // Yg tidak punya koordinat taruh di bawah
      if (aLat == null || aLng == null) return 1;
      if (bLat == null || bLng == null) return -1;

      final dA = _distanceInMeters(cabangLat, cabangLng, aLat, aLng);
      final dB = _distanceInMeters(cabangLat, cabangLng, bLat, bLng);
      return dA.compareTo(dB);
    });
    return sorted;
  }

  Widget _buildKirimTab() {
    final manifestsAsync = ref.watch(manifest_prov.driverActiveManifestsProvider);
    final routeAsync = ref.watch(routeProvider);

    final manifests = manifestsAsync.valueOrNull ?? <Manifest>[];
    final totalResi = manifests.fold<int>(0, (s, m) => s + m.totalResi);
    final totalWorkUnit = manifests.fold<int>(0, (s, m) => s + m.workUnit);
    final isLoading = manifestsAsync.isLoading;
    final hasRoute = routeAsync.valueOrNull != null && !routeAsync.valueOrNull!.isEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (manifests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Tidak ada manifest',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Summary bar
    final summaryBar = Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _summaryStat('${manifests.length}', 'Manifest'),
          Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
          _summaryStat('$totalResi', 'Resi'),
          Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
          _summaryStat('$totalWorkUnit', 'Work Unit'),
        ],
      ),
    );

    if (isWide) {
      // Web/landscape: map 75%, manifest list 25%
      return Column(
        children: [
          summaryBar,
          Expanded(
            flex: 70,
            child: hasRoute
                ? DriverRouteMap(
                    routeData: routeAsync.valueOrNull!,
                    compact: true,
                    driverName: ref.read(authProvider).user?.name,
                  )
                : const Center(
                    child: Text('Tidak ada rute',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
          ),
          Expanded(
            flex: 30,
            child: manifests.isEmpty
                ? const Center(
                    child: Text('Tidak ada manifest',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  )
                : Stack(
                    children: [
                      ListView(
                        controller: _manifestScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(8, 8, 56, 8),
                        children: manifests.map((m) => _buildManifestCompactCard(m)).toList(),
                      ),
                      // Right chevron
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: _buildRightChevron(),
                      ),
                      // Left chevron
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: _buildLeftChevron(),
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

    // Mobile portrait: map di atas (collapsible), list manifest vertikal
    return Column(
      children: [
        summaryBar,
        if (hasRoute)
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DriverRouteMap(
                routeData: routeAsync.valueOrNull!,
                compact: true,
                driverName: ref.read(authProvider).user?.name,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(manifest_prov.driverActiveManifestsProvider);
              ref.invalidate(manifest_prov.manifestStatsProvider);
              ref.invalidate(routeProvider);
              await Future<void>.delayed(const Duration(milliseconds: 100));
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: manifests.length,
              itemBuilder: (_, i) => _buildManifestCard(manifests[i]),
            ),
          ),
        ),
      ],
    );
  }

  // Manifest card with ExpansionTile for mobile
  Widget _buildManifestCard(Manifest m) {
    // Cari koordinat cabang asal untuk sorting jarak
    double? cabangLat;
    double? cabangLng;
    final cabang = CabangLokasiService.findByName(m.asalCabangName);
    if (cabang != null) {
      cabangLat = cabang.latitude;
      cabangLng = cabang.longitude;
    }

    final txs = (cabangLat != null && cabangLng != null)
        ? _sortTransaksiByDistance(m.transactions ?? <Transaction>[], cabangLat, cabangLng)
        : (m.transactions ?? <Transaction>[]);
    final selesai = txs.where((tx) =>
        tx.statusSaatIni == 'diterima' || tx.statusSaatIni == 'diterima_cabang').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: false,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: m.isAntarCabang
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.description_rounded,
            size: 22,
            color: m.isAntarCabang ? AppTheme.primary : Colors.orange,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.noManifest,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  m.isAntarCabang ? Icons.store_rounded : Icons.person_pin_circle_rounded,
                  size: 12,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    m.tujuanNama,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (m.isAntarCabang)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToCabang(m.tujuanNama, lat: m.tujuanLat, lng: m.tujuanLng),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Progress bar
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: txs.isEmpty ? 0 : selesai / txs.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        selesai == txs.length && txs.isNotEmpty
                            ? Colors.green
                            : AppTheme.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$selesai/${txs.length} resi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selesai == txs.length && txs.isNotEmpty
                        ? Colors.green
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${m.workUnit} Work',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Resi list
          ...txs.map((tx) => _buildResiInManifest(tx)),
          const SizedBox(height: 8),
          // Lihat detail button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/dashboard/manifest/${m.id}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Detail Manifest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact card for wide layout
  Widget _buildManifestCompactCard(Manifest m) {
    final txs = m.transactions ?? <Transaction>[];
    final selesai = txs.where((tx) =>
        tx.statusSaatIni == 'diterima' || tx.statusSaatIni == 'diterima_cabang').length;

    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.noManifest,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (m.isAntarCabang)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToCabang(m.tujuanNama, lat: m.tujuanLat, lng: m.tujuanLng),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  m.isAntarCabang ? Icons.store_rounded : Icons.person_pin_circle_rounded,
                  size: 11,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    m.tujuanNama,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _badge(
                  '$selesai/${txs.length} resi',
                  const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 4),
                _badge(
                  '${m.workUnit} Work',
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/dashboard/manifest/${m.id}'),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Detail Manifest', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Individual resi card inside manifest expansion
  Widget _buildResiInManifest(Transaction tx) {
    final selesai = tx.statusSaatIni == 'diterima' || tx.statusSaatIni == 'diterima_cabang';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selesai ? Colors.green.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selesai
              ? Colors.green.withValues(alpha: 0.2)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selesai
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selesai ? Icons.check_circle_rounded : Icons.pending_rounded,
                size: 16,
                color: selesai ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx.noResi,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: selesai ? const Color(0xFF6B7280) : const Color(0xFF0F172A),
                            decoration: selesai ? TextDecoration.lineThrough : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ResiCopyButton(resi: tx.noResi),
                      if (tx.penerimaAddress.isNotEmpty ||
                          (tx.penerimaLatitude != null &&
                              tx.penerimaLongitude != null))
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _navigateToMaps(tx),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.pengirimName} → ${tx.penerimaName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: selesai ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              selesai ? '✅' : tx.beratLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selesai ? Colors.green : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightChevron() {
    final hasClients = _manifestScrollCtrl.hasClients;
    final maxScroll = hasClients ? _manifestScrollCtrl.position.maxScrollExtent : 0;
    if (maxScroll <= 0) return const SizedBox.shrink();
    final atEnd = _manifestScrollPos >= maxScroll - 10;
    return Center(
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.white,
        child: IconButton(
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: atEnd ? const Color(0xFFCBD5E1) : AppTheme.primary,
          ),
          padding: EdgeInsets.zero,
          onPressed: atEnd
              ? null
              : () {
                  if (_manifestScrollCtrl.hasClients) {
                    _manifestScrollCtrl.animateTo(
                      _manifestScrollCtrl.position.pixels + 260,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
        ),
      ),
    );
  }

  Widget _buildLeftChevron() {
    final hasClients = _manifestScrollCtrl.hasClients;
    final maxScroll = hasClients ? _manifestScrollCtrl.position.maxScrollExtent : 0;
    if (maxScroll <= 0) return const SizedBox.shrink();
    final atStart = _manifestScrollPos <= 10;
    return Center(
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.white,
        child: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: atStart ? const Color(0xFFCBD5E1) : AppTheme.primary,
          ),
          padding: EdgeInsets.zero,
          onPressed: atStart
              ? null
              : () {
                  if (_manifestScrollCtrl.hasClients) {
                    _manifestScrollCtrl.animateTo(
                      _manifestScrollCtrl.position.pixels - 260,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _summaryStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatTab() {
    final fmt = DateFormat('dd/MM/yyyy');
    final userId = ref.watch(authProvider.select((s) => s.user?.id));

    final riwayatAsync = ref.watch(manifest_prov.driverRiwayatManifestsProvider(
      manifest_prov.ManifestFilter(
        status: 'selesai',
        page: _riwayatPage,
        limit: 20,
        startDate: _startDate,
        endDate: _endDate,
        userId: userId,
      ),
    ));

    // Accumulate data dari tiap page
    if (riwayatAsync.hasValue) {
      final data = riwayatAsync.value!;
      if (_riwayatPage == 1) {
        _riwayatItems
          ..clear()
          ..addAll(data.manifests);
        _hasMore = data.manifests.length >= 20;
        _riwayatLoading = false;
      } else if (_riwayatLoading && data.manifests.isNotEmpty) {
        // Hindari duplikat page
        final existingIds = _riwayatItems.map((m) => m.id).toSet();
        final newItems = data.manifests.where((m) => !existingIds.contains(m.id)).toList();
        if (newItems.isNotEmpty) {
          _riwayatItems.addAll(newItems);
          _hasMore = data.manifests.length >= 20;
          _riwayatPage++;
        }
        _riwayatLoading = false;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _startDate != null && _endDate != null
                    ? DateTimeRange(start: _startDate!, end: _endDate!)
                    : null,
                helpText: 'Pilih rentang tanggal',
                initialEntryMode: DatePickerEntryMode.calendarOnly,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      surface: Colors.white,
                      surfaceContainerHighest: Colors.white,
                      onSurface: const Color(0xFF0F172A),
                      primary: const Color(0xFF6366F1),
                      onPrimary: Colors.white,
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                      headerBackgroundColor: const Color(0xFF6366F1),
                      headerForegroundColor: Colors.white,
                      todayBackgroundColor: WidgetStateProperty.all(
                        const Color(0xFFEEF2FF),
                      ),
                      todayForegroundColor: WidgetStateProperty.all(
                        const Color(0xFF6366F1),
                      ),
                      dayBackgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF6366F1);
                        }
                        return Colors.transparent;
                      }),
                      dayForegroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return const Color(0xFF0F172A);
                      }),
                      dayOverlayColor: WidgetStateProperty.all(
                        Colors.transparent,
                      ),
                      rangePickerBackgroundColor: Colors.white,
                      rangeSelectionBackgroundColor: const Color(0xFFEEF2FF),
                      dayShape: WidgetStateProperty.all(
                        const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ),
                    dialogTheme: const DialogThemeData(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                    ),
                    inputDecorationTheme: const InputDecorationTheme(
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                  _riwayatPage = 1;
                  _riwayatItems.clear();
                  _hasMore = true;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _startDate != null && _endDate != null
                          ? '${fmt.format(_startDate!)} — ${fmt.format(_endDate!)}'
                          : 'Filter riwayat berdasarkan tanggal',
                      style: TextStyle(
                        fontSize: 12,
                        color: _startDate != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (_startDate != null) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          _riwayatPage = 1;
                          _riwayatItems.clear();
                          _hasMore = true;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: riwayatAsync.isLoading && _riwayatItems.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _riwayatItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada riwayat manifest',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _resetRiwayat();
                        await Future<void>.delayed(const Duration(milliseconds: 100));
                      },
                      child: ListView.builder(
                        controller: _riwayatScrollC,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: _riwayatItems.length + (_hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _riwayatItems.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _RiwayatManifestCard(
                            manifest: _riwayatItems[i],
                            onTapResi: (tx) => _showDetail(tx),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showDetail(Transaction tx) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final showDriver = tx.namaDriver != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, scrollC) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC), // Slate-50 background
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1), // Slate-300 handle
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollC,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Nomor Resi Pengiriman',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                StatusBadge(
                                  status: tx.statusSaatIni,
                                  fontSize: 10,
                                  labelOverride: tx.statusSaatIni == 'diterima_cabang'
                                      ? 'Diterima di ${tx.diterimaDiCabang.isNotEmpty ? tx.diterimaDiCabang : 'Cabang'}'
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    tx.noResi,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                ResiCopyButton(resi: tx.noResi),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sender & Recipient Info
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _penerimaCard(tx)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _infoCard(
                              'Pengirim',
                              tx.pengirimName,
                              tx.pengirim['phone'] as String? ?? '',
                              tx.pengirim['address'] as String? ?? '',
                              Icons.send_rounded,
                              AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Map Card — tampilkan lokasi tujuan (penerima atau cabang)
                    if (tx.tujuanSelanjutnya?['tipe'] == 'penerima' ||
                        tx.tujuanSelanjutnya?['tipe'] == 'cabang') ...[
                      const SizedBox(height: 12),
                      _mapCard(tx),
                    ],

                    // Specs Card
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _infoCell(
                                Icons.scale_rounded,
                                'Berat',
                                tx.beratLabel,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: const Color(0xFFE2E8F0),
                            ),
                            Expanded(
                              child: _infoCell(
                                Icons.inventory_2_rounded,
                                'Jumlah Koli',
                                '${tx.jumlahKoli} koli',
                              ),
                            ),
                            if (tx.biayaKirim > 0) ...[
                              Container(
                                width: 1,
                                height: 40,
                                color: const Color(0xFFE2E8F0),
                              ),
                              Expanded(
                                child: _infoCell(
                                  Icons.payments_rounded,
                                  'Biaya Kirim',
                                  fmt.format(tx.biayaKirim),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Driver details
                    if (showDriver ||
                        (tx.namaPenerimaAkhir != null &&
                            tx.namaPenerimaAkhir!.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDriver)
                              Expanded(
                                child: _infoCard(
                                  'Driver Kurir',
                                  tx.namaDriver!,
                                  tx.kontakDriver ?? '',
                                  '',
                                  Icons.directions_car_filled_rounded,
                                  Colors.amber.shade700,
                                ),
                              ),
                            if (showDriver &&
                                tx.namaPenerimaAkhir != null &&
                                tx.namaPenerimaAkhir!.isNotEmpty)
                              const SizedBox(width: 8),
                            if (tx.namaPenerimaAkhir != null &&
                                tx.namaPenerimaAkhir!.isNotEmpty)
                              Expanded(
                                child: _infoCard(
                                  'Diterima oleh',
                                  tx.namaPenerimaAkhir!,
                                  '',
                                  '',
                                  Icons.check_circle_rounded,
                                  const Color(0xFF10B981),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    const Text(
                      'RIWAYAT PENGIRIMAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TrackingTimeline(logs: tx.trackingLogs),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _penerimaCard(Transaction tx) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.secondary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  Icons.call_received_rounded,
                  size: 14,
                  color: AppTheme.secondary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Penerima',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    tx.penerimaName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx.penerimaAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        tx.penerimaAddress,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if ((tx.penerima['phone'] as String? ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_iphone_rounded,
                    size: 12,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tx.penerima['phone'] as String? ?? '',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: tx.penerima['phone'] as String? ?? '',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nomor telepon disalin'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapCard(Transaction tx) {
    double? lat, lng;
    String titleText;
    final isCabang = tx.tujuanSelanjutnya?['tipe'] == 'cabang';

    if (isCabang) {
      final cabang = CabangLokasiService.findByName(
        tx.tujuanSelanjutnya!['nama'] as String? ?? '',
      );
      if (cabang != null) {
        lat = cabang.latitude;
        lng = cabang.longitude;
      }
      titleText = 'Lokasi Cabang Tujuan (Klik Disini)';
    } else {
      lat = tx.penerimaLatitude;
      lng = tx.penerimaLongitude;
      titleText = 'Lokasi Penerima (Klik Disini)';
    }

    final hasCoords = lat != null && lng != null;
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: false,
        enableFeedback: false,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: Colors.red,
        collapsedIconColor: Colors.red,
        leading: const Icon(
          Icons.location_on_rounded,
          color: Colors.red,
          size: 18,
        ),
        title: Text(
          titleText,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF0F172A),
          ),
        ),
        children: [
          if (hasCoords)
            SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat!, lng!),
                  initialZoom: 15,
                  maxZoom: 18,
                  minZoom: 12,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tracker',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat!, lng!),
                        width: 36,
                        height: 36,
                        child: Icon(
                          isCabang
                              ? Icons.store_rounded
                              : Icons.location_on_rounded,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(lat!, lng!),
                        radius: 1000,
                        color: Colors.red.withValues(alpha: 0.08),
                        borderColor: Colors.red.withValues(alpha: 0.3),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Lokasi belum tersedia',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard(
    String title,
    String name,
    String phone,
    String address,
    IconData icon,
    Color accentColor,
  ) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: accentColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(icon, size: 14, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (phone.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_iphone_rounded,
                    size: 12,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nomor telepon disalin'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Widget card untuk riwayat manifest (selesai)
class _RiwayatManifestCard extends ConsumerStatefulWidget {
  final Manifest manifest;
  final void Function(Transaction) onTapResi;

  const _RiwayatManifestCard({
    required this.manifest,
    required this.onTapResi,
  });

  @override
  ConsumerState<_RiwayatManifestCard> createState() =>
      _RiwayatManifestCardState();
}

class _RiwayatManifestCardState extends ConsumerState<_RiwayatManifestCard> {
  List<Transaction>? _transactions;
  bool _loadingTxs = false;

  Future<void> _loadTransactions() async {
    if (_transactions != null || _loadingTxs) return;
    setState(() => _loadingTxs = true);
    try {
      final res =
          await ApiService().get('${ApiConstants.manifests}/${widget.manifest.id}');
      final data = res.data as Map<String, dynamic>;
      final detail = Manifest.fromJson(data);
      if (!mounted) return;
      setState(() {
        _transactions = detail.transactions ?? [];
        _loadingTxs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTxs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = _transactions ?? <Transaction>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          if (expanded) _loadTransactions();
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle_rounded, size: 22, color: Colors.green),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.manifest.noManifest,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.manifest.tujuanNama} · ${widget.manifest.totalResi} resi · ${widget.manifest.workUnit} work',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (_loadingTxs)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (txs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Memuat data resi...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...txs.map((tx) => _RiwayatResiItem(tx: tx, onTap: () => widget.onTapResi(tx))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/dashboard/manifest/${widget.manifest.id}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Detail Manifest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RiwayatResiItem extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onTap;

  const _RiwayatResiItem({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx.noResi,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Color(0xFF6B7280),
                            decoration: TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ResiCopyButton(resi: tx.noResi),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.pengirimName} → ${tx.penerimaName}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '✅',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
