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

final _kirimProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(transactionRepositoryProvider).getList(status: 'proses_kirim', page: page);
});

final _riwayatProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(transactionRepositoryProvider).getList(status: 'diterima', page: page);
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
          _buildTab(_riwayatProvider, _riwayatPage, (p) => setState(() => _riwayatPage = p)),
        ],
      ),
    );
  }

  Widget _buildTab(
    AutoDisposeFutureProvider<Map<String, dynamic>> Function(int) provider,
    int page,
    ValueChanged<int> onPageChanged,
  ) {
    final async = ref.watch(provider(page));
    final dateFmt = DateFormat('dd/MM/yy HH:mm', 'id_ID');

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, scrollC) => ListView(
          controller: scrollC,
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('No. Resi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        StatusBadge(status: tx.statusSaatIni),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(tx.noResi, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                    child: _infoCard('Penerima', tx.penerimaName, tx.penerima['phone'] as String? ?? '', tx.penerimaAddress, Icons.call_received),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoCard('Pengirim', tx.pengirimName, tx.pengirim['phone'] as String? ?? '', tx.pengirim['address'] as String? ?? '', Icons.send),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _infoCell(Icons.scale, 'Berat', tx.beratLabel)),
                      const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
                      Expanded(child: _infoCell(Icons.inventory_2, 'Koli', '${tx.jumlahKoli}')),
                      if (tx.biayaKirim > 0) ...[
                        const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
                        Expanded(child: _infoCell(Icons.payments, 'Biaya', fmt.format(tx.biayaKirim))),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (tx.namaDriver != null || (tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tx.namaDriver != null)
                      Expanded(
                        child: _infoCard('Driver', tx.namaDriver!, tx.kontakDriver ?? '', '', Icons.person_pin),
                      ),
                    if (tx.namaDriver != null && tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty) const SizedBox(width: 8),
                    if (tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty)
                      Expanded(
                        child: _infoCard('Diterima oleh', tx.namaPenerimaAkhir!, '', '', Icons.check_circle),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Riwayat Tracking', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TrackingTimeline(logs: tx.trackingLogs),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, String name, String phone, String address, IconData icon) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primary.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.black87),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(address, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          if (phone.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppTheme.primary.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Icon(Icons.phone, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(phone, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor telepon disalin'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Icon(Icons.copy, size: 16, color: AppTheme.primary),
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
          Icon(icon, size: 22, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}