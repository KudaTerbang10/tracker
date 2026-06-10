import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final _kirimProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(transactionRepositoryProvider).getList(status: 'proses_kirim', page: page);
});

final _riwayatProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(transactionRepositoryProvider).getList(status: 'diterima,diterima_cabang', tab: 'history', page: page);
});

class DriverTabScreen extends ConsumerStatefulWidget {
  const DriverTabScreen({super.key});
  @override
  ConsumerState<DriverTabScreen> createState() => _DriverTabScreenState();
}

class _DriverTabScreenState extends ConsumerState<DriverTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _kirimPage = 1;
  int _riwayatPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Perlu Dikirim'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab(_kirimProvider, _kirimPage, (p) => setState(() => _kirimPage = p)),
          _buildTab(_riwayatProvider, _riwayatPage, (p) => setState(() => _riwayatPage = p), isRiwayat: true),
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

  Widget _buildTab(
    AutoDisposeFutureProvider<Map<String, dynamic>> Function(int) provider,
    int page,
    ValueChanged<int> onPageChanged, {
    bool isRiwayat = false,
  }) {
    final async = ref.watch(provider(page));
    final dateFmt = DateFormat('dd/MM/yy HH:mm', 'id_ID');
    final currentUserId = ref.read(authProvider).user?.id;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (result) {
        final list = result['data'] as List<Transaction>;
        final totalPages = result['totalPages'] as int;

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

        return Column(
          children: [
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
                    ),
                    Text('Halaman $page dari $totalPages'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
                    ),
                  ],
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
                            if (isRiwayat
                                ? _tujuanUntukDriver(tx, currentUserId) != null
                                : tx.tujuanSelanjutnya != null && (tx.tujuanSelanjutnya!['nama']?.toString() ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.tour, size: 14, color: Colors.orange.shade700),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        () {
                                          final tujuan = isRiwayat ? _tujuanUntukDriver(tx, currentUserId) : tx.tujuanSelanjutnya;
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
      },
    );
  }

  void _showDetail(Transaction tx) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final showDriver = tx.namaDriver != null;
    final isDriver = ref.read(authProvider).user?.isDriver ?? false;

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
                            child: _infoCard(
                              'Penerima',
                              tx.penerimaName,
                              tx.penerima['phone'] as String? ?? '',
                              tx.penerimaAddress,
                              Icons.call_received_rounded,
                              AppTheme.secondary,
                            ),
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

                    // Specs Card
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

  Widget _infoCard(String title, String name, String phone, String address, IconData icon, Color accentColor) {
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
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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