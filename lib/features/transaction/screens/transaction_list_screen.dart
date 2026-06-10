import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/constants/api_constants.dart';

final _listProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) {
  final parts = key.split('|');
  final page = int.parse(parts[0]);
  final tab = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  final status = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
  final search = parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null;
  return ref.read(transactionRepositoryProvider).getList(page: page, tab: tab, status: status, search: search);
});

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});
  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> with SingleTickerProviderStateMixin {
  int _pageProses = 1;
  int _pageHistory = 1;
  TabController? _tabController;
  bool get _isAdminCabang => ref.read(authProvider).user?.isAdminCabang ?? false;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = '';
  int _pageAll = 1;

  static const _statusFilters = [
    '',
    'diterima_cabang',
    'proses_kirim',
    'diterima',
  ];

  String _listKey(int page, {String? tab, String? status, String? search}) =>
      '$page|${tab ?? ''}|${status ?? ''}|${search ?? ''}';

  void _applyFilter() {
    ref.invalidate(_listProvider(_listKey(_pageAll, status: _selectedStatus, search: _searchQuery)));
  }

  @override
  void initState() {
    super.initState();
    if (_isAdminCabang) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanAndSearch() async {
    final code = await BarcodeScannerDialog.show(context, label: 'Scan barcode untuk mencari transaksi');
    if (code != null && code.isNotEmpty) {
      _searchController.text = code;
      setState(() {
        _searchQuery = code;
        _pageAll = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yy HH:mm', 'id_ID');
    final isAdminCabang = _isAdminCabang;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Transaksi'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        bottom: isAdminCabang
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Proses'),
                  Tab(text: 'History (3 hari)'),
                ],
              )
            : null,
      ),
      body: isAdminCabang
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildTab('$_pageProses|current', (p) => setState(() => _pageProses = p), dateFmt),
                _buildTab('$_pageHistory|history', (p) => setState(() => _pageHistory = p), dateFmt),
              ],
            )
          : _buildSuperAdminView(dateFmt),
    );
  }

  Widget _buildSuperAdminView(DateFormat dateFmt) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari no. resi...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _pageAll = 1;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanAndSearch,
                  ),
                ],
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            ),
            onChanged: (v) {
              setState(() {
                _searchQuery = v;
                _pageAll = 1;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.map((s) {
                final selected = _selectedStatus == s;
                final label = s.isEmpty ? 'Semua' : StatusList.label(s);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      _applyFilter();
                      setState(() {
                        _selectedStatus = s;
                        _pageAll = 1;
                      });
                    },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(child: _buildTab(_listKey(_pageAll, status: _selectedStatus, search: _searchQuery), (p) => setState(() => _pageAll = p), dateFmt)),
      ],
    );
  }

  Widget _buildTab(String key, ValueChanged<int> onPageChanged, DateFormat dateFmt) {
    final parts = key.split('|');
    final page = int.parse(parts[0]);
    final async = ref.watch(_listProvider(key));
    final tab = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;

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
                Text(tab == 'history' ? 'Tidak ada riwayat 3 hari terakhir' : 'Belum ada transaksi', style: TextStyle(color: Colors.grey.shade500)),
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
                  final user = ref.read(authProvider).user;
                  final isDriver = user?.isDriver ?? false;
                  final canDelete = tab != 'history' && _canDelete(tx, user);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(tx.noResi, style: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 1), overflow: TextOverflow.ellipsis)),
                            if (!isDriver) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => LabelPrinter.printBarcodeLabel(
                                  data: tx.noResi,
                                  pengirim: tx.pengirim,
                                  penerima: tx.penerima,
                                  paket: tx.paket,
                                  createdAt: tx.createdAt,
                                  asal: tx.createdBy['cabang_name']?.toString() ??
                                      tx.createdBy['konter_name']?.toString() ??
                                      tx.createdBy['gudang_name']?.toString(),
                                  dicetakOleh: user?.lokasi?['name']?.toString(),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.print, size: 16, color: AppTheme.primary),
                                ),
                              ),
                            ],
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
                        onLongPress: canDelete ? () => _confirmDelete(tx) : null,
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

  Future<void> _confirmDelete(Transaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text('Transaksi dengan No. Resi ${tx.noResi} akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(transactionRepositoryProvider).delete(tx.id);
      if (!mounted) return;
      ref.invalidate(_listProvider('$_pageProses|current'));
      ref.invalidate(_listProvider('$_pageHistory|history'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaksi ${tx.noResi} berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  bool _canDelete(Transaction tx, User? user) {
    if (user == null) return false;
    if (!user.isAdminCabang) return false;
    if (tx.statusSaatIni != 'diterima_cabang') return false;
    if (tx.trackingLogs.isNotEmpty) {
      final firstCabang = tx.trackingLogs.first.lokasi?['cabang_id']?.toString();
      if (firstCabang != null) return firstCabang == user.cabangId;
    }
    return tx.trackingLogs.length == 1;
  }
  void _showDetail(Transaction tx) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final showDriver = _isDeliveredToRecipient(tx) && tx.namaDriver != null;
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
                                if (!isDriver) ...[
                                  const SizedBox(width: 8),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => LabelPrinter.printBarcodeLabel(
                                        data: tx.noResi,
                                        pengirim: tx.pengirim,
                                        penerima: tx.penerima,
                                        paket: tx.paket,
                                        createdAt: tx.createdAt,
                                        asal: tx.createdBy['cabang_name']?.toString() ??
                                            tx.createdBy['konter_name']?.toString() ??
                                            tx.createdBy['gudang_name']?.toString(),
                                        dicetakOleh: ref.read(authProvider).user?.lokasi?['name']?.toString(),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.print_rounded, size: 16, color: AppTheme.primary),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sender & Recipient Cards
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

                    // Spec Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Row(
                          children: [
                            Expanded(child: _InfoCell(icon: Icons.scale_rounded, label: 'Berat', value: tx.beratLabel)),
                            Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                            Expanded(child: _InfoCell(icon: Icons.inventory_2_rounded, label: 'Jumlah Koli', value: '${tx.jumlahKoli} koli')),
                            if (tx.biayaKirim > 0) ...[
                              Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                              Expanded(child: _InfoCell(icon: Icons.payments_rounded, label: 'Biaya Kirim', value: fmt.format(tx.biayaKirim))),
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
                                child: _InfoCard(
                                  title: 'Driver Kurir',
                                  name: tx.namaDriver!,
                                  phone: tx.kontakDriver ?? '',
                                  address: '',
                                  icon: Icons.directions_car_filled_rounded,
                                  accentColor: Colors.amber.shade700,
                                ),
                              ),
                            if (showDriver && tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty) const SizedBox(width: 8),
                            if (tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty)
                              Expanded(
                                child: _InfoCard(
                                  title: 'Diterima oleh',
                                  name: tx.namaPenerimaAkhir!,
                                  phone: '',
                                  address: '',
                                  icon: Icons.check_circle_rounded,
                                  accentColor: Colors.green.shade600,
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

  bool _isDeliveredToRecipient(Transaction tx) {
    if (tx.statusSaatIni == 'proses_kirim' || tx.statusSaatIni == 'diterima') return true;
    final tipe = tx.tujuanSelanjutnya?['tipe'] as String?;
    if (tipe == 'penerima') return true;
    for (final log in tx.trackingLogs) {
      if (log.status == 'keluar_cabang') {
        if (log.tujuan?['tipe'] == 'penerima') return true;
      }
    }
    return false;
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
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCell({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
