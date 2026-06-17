import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/route_provider.dart';
import '../utils/route_optimizer.dart';
import '../widgets/driver_route_map.dart';

final _kirimProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.read(transactionRepositoryProvider).getList(status: 'proses_kirim', limit: 999);
});

class DriverTabScreen extends ConsumerStatefulWidget {
  const DriverTabScreen({super.key});
  @override
  ConsumerState<DriverTabScreen> createState() => _DriverTabScreenState();
}

class _DriverTabScreenState extends ConsumerState<DriverTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // infinite scroll riwayat
  final _riwayatItems = <Transaction>[];
  int _riwayatPage = 1;
  int _riwayatTotalPages = 1;
  bool _riwayatLoadingMore = false;
  final _riwayatScrollC = ScrollController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        if (_tabController.index == 1) _loadRiwayat();
      }
    });
    _riwayatScrollC.addListener(() {
      if (_riwayatScrollC.position.pixels >= _riwayatScrollC.position.maxScrollExtent - 200) {
        _loadRiwayat();
      }
    });
    _loadRiwayat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _riwayatScrollC.dispose();
    super.dispose();
  }

  Future<void> _loadRiwayat() async {
    if (_riwayatLoadingMore || _riwayatPage > _riwayatTotalPages) return;
    if (_riwayatPage == 1) _riwayatItems.clear();
    _riwayatLoadingMore = true;
    try {
      final result = await ref.read(transactionRepositoryProvider).getList(
        tab: 'history',
        page: _riwayatPage,
        startDate: _startDate,
        endDate: _endDate,
      );
      _riwayatTotalPages = result['totalPages'] as int;
      _riwayatItems.addAll(result['data'] as List<Transaction>);
      _riwayatPage++;
    } finally {
      _riwayatLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  void _resetRiwayat() {
    _riwayatPage = 1;
    _riwayatTotalPages = 1;
    _riwayatItems.clear();
    _loadRiwayat();
  }

  @override
  Widget build(BuildContext context) {
    final kirimAsync = ref.watch(_kirimProvider);
    final kirimData = kirimAsync.valueOrNull;
    final kirimCount = kirimData != null ? (kirimData['data'] as List<dynamic>).length : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Perlu Dikirim'),
                  if (kirimCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$kirimCount',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
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
        children: [
          _buildKirimTab(),
          _buildRiwayatTab(),
        ],
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

  Widget _buildKirimTab() {
    final async = ref.watch(_kirimProvider);
    final routeAsync = ref.watch(routeProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (result) {
        final list = result['data'] as List<Transaction>;

        // Urutkan berdasarkan jarak dari cabang (terdekat → terjauh)
        final cabangPos = routeAsync.valueOrNull?.start;
        if (cabangPos != null) {
          list.sort((a, b) {
            final aLat = a.penerimaLatitude;
            final aLng = a.penerimaLongitude;
            final bLat = b.penerimaLatitude;
            final bLng = b.penerimaLongitude;
            if (aLat == null || aLng == null) return 1;
            if (bLat == null || bLng == null) return -1;
            final da = haversine(cabangPos, LatLng(aLat, aLng));
            final db = haversine(cabangPos, LatLng(bLat, bLng));
            return da.compareTo(db);
          });
        }

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Tidak ada data', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final hasRoute = routeAsync.valueOrNull != null && !routeAsync.valueOrNull!.isEmpty;
        final screenWidth = MediaQuery.of(context).size.width;
        final isWide = screenWidth >= 600;

        if (isWide) {
          // Web / landscape: map 75% tinggi, card horizontal 25%
          return Column(
            children: [
              // Map — 75% tinggi
              Expanded(
                flex: 75,
                child: hasRoute
                    ? DriverRouteMap(routeData: routeAsync.valueOrNull!, compact: true)
                    : const Center(
                        child: Text(
                          'Tidak ada rute',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
              ),
              // Card horizontal — 25% tinggi
              Expanded(
                flex: 25,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final tx = list[i];
                    return SizedBox(
                      width: screenWidth * 0.23,
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showDetail(tx),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF97316),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        tx.noResi,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${tx.pengirimName} → ${tx.penerimaName}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const Spacer(),
                                if (tx.tujuanSelanjutnya != null && (tx.tujuanSelanjutnya!['nama']?.toString() ?? '').isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                                    ),
                                    child: Text(
                                      () {
                                        final nama = tx.tujuanSelanjutnya!['nama']?.toString() ?? '';
                                        final tipe = tx.tujuanSelanjutnya!['tipe']?.toString() ?? '';
                                        return tipe == 'penerima' ? 'Antar ke $nama' : 'Antar ke $nama';
                                      }(),
                                      style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        // Mobile portrait: map di atas, list card vertical di bawah
        return Column(
          children: [
            if (hasRoute)
              SizedBox(
                height: 250,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: DriverRouteMap(routeData: routeAsync.valueOrNull!, compact: true),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final tx = list[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showDetail(tx),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_shipping_rounded, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tx.noResi,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                ResiCopyButton(resi: tx.noResi),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${tx.pengirimName} → ${tx.penerimaName}',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tx.tujuanSelanjutnya != null && (tx.tujuanSelanjutnya!['nama']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.tour, size: 14, color: Colors.orange.shade700),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        () {
                                          final nama = tx.tujuanSelanjutnya!['nama']?.toString() ?? '';
                                          final tipe = tx.tujuanSelanjutnya!['tipe']?.toString() ?? '';
                                          return tipe == 'penerima' ? 'Antar ke $nama (penerima)' : 'Antar ke $nama';
                                        }(),
                                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
              },
            );
          }

  Widget _buildRiwayatTab() {
    final dateFmt = DateFormat('dd/MM/yy HH:mm', 'id_ID');
    final currentUserId = ref.read(authProvider).user?.id;
    final fmt = DateFormat('dd/MM/yyyy');

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
                      todayBackgroundColor: WidgetStateProperty.all(const Color(0xFFEEF2FF)),
                      todayForegroundColor: WidgetStateProperty.all(const Color(0xFF6366F1)),
                      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) return const Color(0xFF6366F1);
                        return Colors.transparent;
                      }),
                      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) return Colors.white;
                        return const Color(0xFF0F172A);
                      }),
                      dayOverlayColor: WidgetStateProperty.all(Colors.transparent),
                      rangePickerBackgroundColor: Colors.white,
                      rangeSelectionBackgroundColor: const Color(0xFFEEF2FF),
                      dayShape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                    ),
                    dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
                    inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: Colors.white),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                  _resetRiwayat();
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
                  const Icon(Icons.date_range, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _startDate != null && _endDate != null
                          ? '${fmt.format(_startDate!)} — ${fmt.format(_endDate!)}'
                          : 'Filter riwayat berdasarkan tanggal',
                      style: TextStyle(
                        fontSize: 12,
                        color: _startDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (_startDate != null) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          _resetRiwayat();
                        });
                      },
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _riwayatItems.isEmpty && !_riwayatLoadingMore
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Tidak ada riwayat', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _riwayatScrollC,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _riwayatItems.length + (_riwayatPage <= _riwayatTotalPages ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _riwayatItems.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final tx = _riwayatItems[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          tx.statusSaatIni == 'diterima' ? Icons.check_circle : Icons.local_shipping,
                          color: tx.statusSaatIni == 'diterima' ? Colors.green : Colors.orange,
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(tx.noResi, style: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 4),
                            ResiCopyButton(resi: tx.noResi),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${tx.pengirimName} → ${tx.penerimaName}'),
                              if (_tujuanUntukDriver(tx, currentUserId) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.tour, size: 14, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          () {
                                            final tujuan = _tujuanUntukDriver(tx, currentUserId);
                                            final nama = tujuan?['nama']?.toString() ?? '';
                                            final tipe = tujuan?['tipe']?.toString() ?? '';
                                            return tipe == 'penerima' ? 'Mengantar ke $nama (penerima)' : 'Mengantar ke $nama';
                                          }(),
                                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(dateFmt.format(toJakarta(tx.createdAt)), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                        trailing: StatusBadge(status: tx.statusSaatIni),
                        onTap: () => _showDetail(tx),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

    void _showDetail(Transaction tx) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
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
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                                StatusBadge(status: tx.statusSaatIni, fontSize: 10),
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
                          Expanded(
                            child: _penerimaCard(tx),
                          ),
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

                    // Map Card — only for delivery to recipient
                    if (tx.tujuanSelanjutnya?['tipe'] == 'penerima') ...[
                      const SizedBox(height: 12),
                      _mapCard(tx),
                    ],

                    // Specs Card
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Row(
                          children: [
                            Expanded(child: _infoCell(Icons.scale_rounded, 'Berat', tx.beratLabel)),
                            Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                            Expanded(child: _infoCell(Icons.inventory_2_rounded, 'Jumlah Koli', '${tx.jumlahKoli} koli')),
                            if (tx.biayaKirim > 0) ...[
                              Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                              Expanded(child: _infoCell(Icons.payments_rounded, 'Biaya Kirim', fmt.format(tx.biayaKirim))),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Driver details
                    if (showDriver || (tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty)) ...[
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
                            if (showDriver && tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty) const SizedBox(width: 8),
                            if (tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty)
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
                Icon(Icons.call_received_rounded, size: 14, color: AppTheme.secondary),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx.penerimaAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        tx.penerimaAddress,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
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
                border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tx.penerima['phone'] as String? ?? '',
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: tx.penerima['phone'] as String? ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor telepon disalin'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapCard(Transaction tx) {
    final hasCoords = tx.penerimaLatitude != null && tx.penerimaLongitude != null;
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
        leading: const Icon(Icons.location_on_rounded, color: Colors.red, size: 18),
        title: const Text(
          'Lokasi Penerima (Klik Disini)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
        ),
        children: [
          if (hasCoords)
            SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(tx.penerimaLatitude!, tx.penerimaLongitude!),
                  initialZoom: 15,
                  maxZoom: 18,
                  minZoom: 12,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tracker',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(tx.penerimaLatitude!, tx.penerimaLongitude!),
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 36),
                      ),
                    ],
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(tx.penerimaLatitude!, tx.penerimaLongitude!),
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

  Widget _infoCard(String title, String name, String phone, String address, IconData icon, Color accentColor) {
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
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 12),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
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
                border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor telepon disalin'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
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
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}