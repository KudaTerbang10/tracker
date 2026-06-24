import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/track_repository.dart';
import '../../../shared/utils/cabang_lokasi_service.dart';
import 'package:intl/intl.dart';

final trackProvider = FutureProvider.autoDispose.family<Transaction, String>((
  ref,
  noResi,
) {
  return ref.read(trackRepositoryProvider).trackByResi(noResi);
});

class TrackResultScreen extends ConsumerWidget {
  final String noResi;
  const TrackResultScreen({super.key, required this.noResi});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trackProvider(noResi));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.go('/'),
                  ),
                  const Spacer(),
                  const Text(
                    'Detail Tracking',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) {
                  String msg;
                  IconData icon;
                  if (e is DioException &&
                      e.type == DioExceptionType.connectionError) {
                    msg =
                        'Tidak dapat terhubung ke server.\nPastikan backend berjalan.';
                    icon = Icons.wifi_off_rounded;
                  } else if (e is DioException &&
                      (e.type == DioExceptionType.connectionTimeout ||
                          e.type == DioExceptionType.receiveTimeout)) {
                    msg = 'Waktu koneksi habis.\nCoba lagi nanti.';
                    icon = Icons.timer_off_rounded;
                  } else {
                    msg = 'Resi "$noResi" tidak ditemukan';
                    icon = Icons.search_off_rounded;
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 64, color: const Color(0xFF94A3B8)),
                          const SizedBox(height: 16),
                          Text(
                            msg,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 160,
                            child: ElevatedButton(
                              onPressed: () => context.go('/'),
                              child: const Text('Kembali'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (tx) => _TrackDetail(tx: tx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackDetail extends StatelessWidget {
  final Transaction tx;
  const _TrackDetail({required this.tx});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      StatusBadge(status: tx.statusSaatIni, fontSize: 10),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.noResi,
                          style: const TextStyle(
                            fontSize: 20,
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InfoCard(
                    title: 'Penerima',
                    name: tx.penerimaName,
                    phone: tx.penerima['phone'] as String? ?? '',
                    address: tx.penerimaAddress,
                    icon: Icons.call_received_rounded,
                    accentColor: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoCard(
                    title: 'Pengirim',
                    name: tx.pengirimName,
                    phone: tx.pengirim['phone'] as String? ?? '',
                    address: tx.pengirim['address'] as String? ?? '',
                    icon: Icons.send_rounded,
                    accentColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.scale_rounded,
                      label: 'Berat',
                      value: tx.beratLabel,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.inventory_2_rounded,
                      label: 'Jumlah Koli',
                      value: '${tx.jumlahKoli} koli',
                    ),
                  ),
                  if (tx.biayaKirim > 0) ...[
                    Container(
                      width: 1,
                      height: 40,
                      color: const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: _InfoCell(
                        icon: Icons.payments_rounded,
                        label: 'Biaya Kirim',
                        value: fmt.format(tx.biayaKirim),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TrackingMap(tx: tx),
          if (tx.namaDriver != null && tx.tujuanSelanjutnya?['tipe'] != 'cabang') ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Driver Kurir',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx.namaDriver!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (tx.kontakDriver != null &&
                              tx.kontakDriver!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  tx.kontakDriver!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: tx.kontakDriver!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Nomor telepon driver disalin'), duration: Duration(seconds: 1)),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.content_copy_rounded, size: 14, color: Color(0xFF6366F1)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (tx.namaPenerimaAkhir != null &&
              tx.namaPenerimaAkhir!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Diterima oleh',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx.namaPenerimaAkhir!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    );
  }
}

class TrackingMap extends StatefulWidget {
  final Transaction tx;
  const TrackingMap({super.key, required this.tx});

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  LatLng? _origin;
  LatLng? _dest;
  String _originName = '';
  String _destName = '';
  bool _isDestCabang = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await CabangLokasiService.init();
    final tx = widget.tx;

    // Cari origin: titik terakhir paket discan (keluar_cabang = cabang keberangkatan)
    for (final log in tx.trackingLogs.reversed) {
      if (log.status == 'keluar_cabang' && log.lokasiName.isNotEmpty) {
        final c = CabangLokasiService.findByName(log.lokasiName);
        if (c != null && c.latitude != null && c.longitude != null) {
          _origin = LatLng(c.latitude!, c.longitude!);
          _originName = log.lokasiName;
        }
        break;
      }
    }

    // Fallback: pakai diterima_cabang pertama
    if (_origin == null) {
      for (final log in tx.trackingLogs) {
        if (log.status == 'diterima_cabang' && log.lokasiName.isNotEmpty) {
          final c = CabangLokasiService.findByName(log.lokasiName);
          if (c != null && c.latitude != null && c.longitude != null) {
            _origin = LatLng(c.latitude!, c.longitude!);
            _originName = log.lokasiName;
          }
          break;
        }
      }
    }

    // Cari tujuan dari tracking_log keluar_cabang/proses_kirim
    for (final log in tx.trackingLogs.reversed) {
      if ((log.status == 'keluar_cabang' || log.status == 'proses_kirim') &&
          log.tujuan != null) {
        final nama = log.tujuan!['nama'] as String? ?? '';
        final tipe = log.tujuan!['tipe'] as String? ?? '';
        if (nama.isNotEmpty) {
          _destName = nama;
          _isDestCabang = tipe == 'cabang';
          if (_isDestCabang) {
            final c = CabangLokasiService.findByName(nama);
            if (c != null && c.latitude != null && c.longitude != null) {
              _dest = LatLng(c.latitude!, c.longitude!);
            }
          }
          break;
        }
      }
    }

    // Fallback: dari tujuanSelanjutnya
    if (_dest == null && tx.tujuanSelanjutnya != null) {
      final nama = tx.tujuanSelanjutnya!['nama'] as String? ?? '';
      final tipe = tx.tujuanSelanjutnya!['tipe'] as String? ?? '';
      if (nama.isNotEmpty) {
        _destName = nama;
        _isDestCabang = tipe == 'cabang';
        if (_isDestCabang) {
          final c = CabangLokasiService.findByName(nama);
          if (c != null && c.latitude != null && c.longitude != null) {
            _dest = LatLng(c.latitude!, c.longitude!);
          }
        }
      }
    }

    // Jika tujuan penerima, pakai koordinat penerima
    if (!_isDestCabang &&
        tx.penerimaLatitude != null &&
        tx.penerimaLongitude != null) {
      _dest = LatLng(tx.penerimaLatitude!, tx.penerimaLongitude!);
      if (_destName.isEmpty) _destName = tx.penerimaName;
    }

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Card(
        child: SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_origin == null) return const SizedBox.shrink();

    final isDiterima = widget.tx.statusSaatIni == 'diterima';
    final isDiterimaCabang = widget.tx.statusSaatIni == 'diterima_cabang';
    final points = <LatLng>[if (!isDiterima) _origin!];
    final markers = <Marker>[];

    if (!isDiterima) {
      // Origin marker
      final cabangColor = isDiterimaCabang ? const Color(0xFFF97316) : const Color(0xFF2563EB);
      markers.add(
        Marker(
          point: _origin!,
          width: 120,
          height: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  isDiterimaCabang ? 'Cabang $_originName' : _originName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: cabangColor,
                    shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: cabangColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDiterimaCabang ? Icons.store_rounded : Icons.flag_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_dest != null && !isDiterimaCabang) {
      points.add(_dest!);

      // Status diterima: hanya marker hijau checklist
      if (isDiterima) {
        markers.clear();
        final diterimaOleh = widget.tx.namaPenerimaAkhir ?? '';
        markers.add(
          Marker(
            point: _dest!,
            width: 140,
            height: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _destName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                      shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                if (diterimaOleh.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Diterima $diterimaOleh',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                      shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      } else {
        // Destination marker reguler
        markers.add(
          Marker(
            point: _dest!,
            width: 120,
            height: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    _destName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _isDestCabang
                          ? const Color(0xFFF97316)
                          : Colors.red,
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _isDestCabang ? const Color(0xFFF97316) : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isDestCabang
                        ? Icons.store_rounded
                        : Icons.location_on_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        );

        // Truck icon di 35% dari titik asal
        final truckPos = LatLng(
          _origin!.latitude * 0.65 + _dest!.latitude * 0.35,
          _origin!.longitude * 0.65 + _dest!.longitude * 0.35,
        );
        final angle = atan2(
          _dest!.latitude - _origin!.latitude,
          _dest!.longitude - _origin!.longitude,
        );
        markers.add(
          Marker(
            point: truckPos,
            width: 30,
            height: 30,
            child: Tooltip(
              message: widget.tx.namaDriver ?? 'Driver',
              child: GestureDetector(
                onTap: () {
                  if (widget.tx.namaDriver != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.tx.namaDriver!),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(0, 0, cos(angle) < 0 ? -1 : 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Bounds
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      minLat = minLat == null
          ? p.latitude
          : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = maxLat == null
          ? p.latitude
          : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = minLng == null
          ? p.longitude
          : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = maxLng == null
          ? p.longitude
          : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    final pad = 0.005;
    final bounds = LatLngBounds(
      LatLng(minLat! - pad, minLng! - pad),
      LatLng(maxLat! + pad, maxLng! + pad),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const Icon(
                  Icons.map_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  isDiterimaCabang
                      ? 'Paket di Cabang'
                      : _isDestCabang
                          ? 'Rute ke Cabang Tujuan'
                          : 'Rute ke Penerima',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.tx.statusSaatIni.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: isDiterima || isDiterimaCabang
                    ? null
                    : CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(15),
                      ),
                initialCenter: isDiterima && _dest != null
                    ? _dest!
                    : isDiterimaCabang && _origin != null
                        ? _origin!
                        : const LatLng(0, 0),
                initialZoom: isDiterima || isDiterimaCabang ? 18 : 10,
                maxZoom: 18,
                minZoom: 4,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tracker',
                ),
                if (points.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline<Object>(
                        points: points,
                        color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title, name, phone, address;
  final IconData icon;
  final Color accentColor;

  const _InfoCard({
    required this.title,
    required this.name,
    required this.phone,
    required this.address,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: phone));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nomor telepon disalin'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.content_copy_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
