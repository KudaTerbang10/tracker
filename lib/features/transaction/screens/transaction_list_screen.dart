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
import '../../../shared/utils/branch_report_printer.dart';
import '../../../shared/utils/driver_report_printer.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/constants/api_constants.dart';

final _prosesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.read(transactionRepositoryProvider).getList(tab: 'current', limit: 999);
});

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});
  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool get _isAdminCabang => ref.read(authProvider).user?.isAdminCabang ?? false;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = '';

  // Infinite scroll untuk history tab
  final _historyItems = <Transaction>[];
  int _historyPage = 1;
  int _historyTotalPages = 1;
  bool _historyLoadingMore = false;
  final _historyScrollC = ScrollController();
  DateTime? _startDate;
  DateTime? _endDate;

  // Infinite scroll untuk super admin
  final _superAdminItems = <Transaction>[];
  int _superAdminPage = 1;
  int _superAdminTotalPages = 1;
  bool _superAdminLoadingMore = false;
  final _superAdminScrollC = ScrollController();

  static const _statusFilters = [
    '',
    'diterima_cabang',
    'proses_kirim',
    'diterima',
  ];

  @override
  void initState() {
    super.initState();
    if (_isAdminCabang) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {});
          if (_tabController!.index == 1) _loadHistory();
        }
      });
      _historyScrollC.addListener(() {
        if (_historyScrollC.position.pixels >= _historyScrollC.position.maxScrollExtent - 200) {
          _loadHistory();
        }
      });
    } else {
      _superAdminScrollC.addListener(() {
        if (_superAdminScrollC.position.pixels >= _superAdminScrollC.position.maxScrollExtent - 200) {
          _loadSuperAdmin();
        }
      });
    }
    _loadHistory();
    if (!_isAdminCabang) _loadSuperAdmin();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _historyScrollC.dispose();
    _superAdminScrollC.dispose();
    super.dispose();
  }

  Future<void> _showMonthYearPicker(String type) async {
    final now = DateTime.now();
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => _MonthYearPickerDialog(
        initialMonth: now.month,
        initialYear: now.year,
        label: type == 'driver' ? 'Laporan Kerja Driver' : 'Laporan Per Cabang',
      ),
    );

    if (result == null || !mounted) return;
    _generateReport(type: type, month: result['month']!, year: result['year']!);
  }

  Future<void> _generateReport({required String type, required int month, required int year}) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final repo = ref.read(transactionRepositoryProvider);
      final List<Map<String, dynamic>> data;
      if (type == 'driver') {
        data = await repo.getDriverReport(month: month, year: year);
      } else {
        data = await repo.getPerCabangReport(month: month, year: year);
      }

      if (mounted) Navigator.of(context).pop();

      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data untuk bulan yang dipilih')),
        );
        return;
      }

      if (type == 'driver') {
        await DriverReportPrinter.printReport(month: month, year: year, data: data);
      } else {
        await BranchReportPrinter.printReport(month: month, year: year, data: data);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data: $e')),
      );
    }
  }

  Future<void> _loadSuperAdmin() async {
    if (_superAdminLoadingMore || _superAdminPage > _superAdminTotalPages) return;
    if (_superAdminPage == 1) _superAdminItems.clear();
    _superAdminLoadingMore = true;
    try {
      final result = await ref.read(transactionRepositoryProvider).getList(
        page: _superAdminPage,
        status: _selectedStatus.isEmpty ? null : _selectedStatus,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        limit: 20,
      );
      final list = result['data'] as List<Transaction>;
      _superAdminTotalPages = result['totalPages'] as int;
      _superAdminItems.addAll(list);
      _superAdminPage++;
    } finally {
      _superAdminLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  void _resetSuperAdmin() {
    _superAdminPage = 1;
    _superAdminTotalPages = 1;
    _superAdminItems.clear();
    _loadSuperAdmin();
  }

  Future<void> _loadHistory() async {
    if (_historyLoadingMore || _historyPage > _historyTotalPages) return;
    if (_historyPage == 1) _historyItems.clear();
    _historyLoadingMore = true;
    try {
      final result = await ref.read(transactionRepositoryProvider).getList(
        page: _historyPage,
        tab: 'history',
        startDate: _startDate,
        endDate: _endDate,
      );
      final list = result['data'] as List<Transaction>;
      _historyTotalPages = result['totalPages'] as int;
      _historyItems.addAll(list);
      _historyPage++;
    } finally {
      _historyLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  void _resetHistory() {
    _historyPage = 1;
    _historyTotalPages = 1;
    _historyItems.clear();
    _loadHistory();
  }

  Future<void> _scanAndSearch() async {
    final code = await BarcodeScannerDialog.show(context, label: 'Scan barcode untuk mencari transaksi');
    if (code != null && code.isNotEmpty) {
      _searchController.text = code;
      setState(() {
        _searchQuery = code;
        _resetSuperAdmin();
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
        actions: [
          if (!isAdminCabang)
            PopupMenuButton<String>(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Cetak Laporan',
              surfaceTintColor: Colors.transparent,
              color: Colors.white,
              onSelected: (v) => _showMonthYearPicker(v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'cabang', child: Row(children: [Icon(Icons.store, size: 18), SizedBox(width: 10), Text('Laporan Per Cabang')])),
                const PopupMenuItem(value: 'driver', child: Row(children: [Icon(Icons.directions_car, size: 18), SizedBox(width: 10), Text('Laporan Kerja Driver')])),
              ],
            ),
        ],
        bottom: isAdminCabang
            ? TabBar(
                controller: _tabController,
                tabs: [
                  _buildProsesTabBadge(),
                  const Tab(text: 'History'),
                ],
              )
            : null,
      ),
      body: isAdminCabang
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildProsesTab(dateFmt),
                _buildHistoryTab(dateFmt),
              ],
            )
          : _buildPaginatedSuperAdminView(dateFmt),
    );
  }

  Widget _buildPaginatedSuperAdminView(DateFormat dateFmt) {
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
                          _resetSuperAdmin();
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
                _resetSuperAdmin();
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
                      setState(() {
                        _selectedStatus = s;
                        _resetSuperAdmin();
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
        Expanded(child: _buildSuperAdminList(dateFmt)),
      ],
    );
  }

  Widget _buildSuperAdminList(DateFormat dateFmt) {
    if (_superAdminItems.isEmpty && _superAdminLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_superAdminItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Tidak ada transaksi', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _superAdminScrollC,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _superAdminItems.length + (_superAdminPage <= _superAdminTotalPages ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _superAdminItems.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _buildItemCard(_superAdminItems[i], dateFmt, canDelete: false);
      },
    );
  }
  Widget _buildProsesTabBadge() {
    final async = ref.watch(_prosesProvider);
    final data = async.valueOrNull;
    final count = data != null ? (data['data'] as List<dynamic>).length : 0;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Proses'),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProsesTab(DateFormat dateFmt) {
    final async = ref.watch(_prosesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (result) {
        final list = result['data'] as List<Transaction>;

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Belum ada transaksi proses', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: list.length,
          itemBuilder: (_, i) => _buildItemCard(list[i], dateFmt, canDelete: true),
        );
      },
    );
  }

  Widget _buildHistoryTab(DateFormat dateFmt) {
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
                  _resetHistory();
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
                          : 'Filter berdasarkan tanggal',
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
                          _resetHistory();
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
          child: _historyItems.isEmpty && !_historyLoadingMore
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Tidak ada riwayat transaksi', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _historyScrollC,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _historyItems.length + (_historyPage <= _historyTotalPages ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _historyItems.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return _buildItemCard(_historyItems[i], dateFmt, canDelete: false);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Transaction tx, DateFormat dateFmt, {required bool canDelete}) {
    final user = ref.read(authProvider).user;
    final isDriver = user?.isDriver ?? false;
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
        onLongPress: canDelete && _canDelete(tx, user) ? () => _confirmDelete(tx) : null,
      ),
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
      ref.invalidate(_prosesProvider);
      _resetHistory();
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

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  final String label;

  const _MonthYearPickerDialog({
    required this.initialMonth,
    required this.initialYear,
    this.label = 'Cetak Laporan',
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _month;
  late int _year;

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(now.year - 2022 + 1, (i) => 2023 + i);

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(widget.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _month,
            decoration: const InputDecoration(
              labelText: 'Bulan',
              border: OutlineInputBorder(),
            ),
            items: List.generate(12, (i) {
              return DropdownMenuItem(value: i + 1, child: Text(_months[i]));
            }),
            onChanged: (v) {
              if (v != null) setState(() => _month = v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _year,
            decoration: const InputDecoration(
              labelText: 'Tahun',
              border: OutlineInputBorder(),
            ),
            items: years.map((y) {
              return DropdownMenuItem(value: y, child: Text(y.toString()));
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _year = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({'month': _month, 'year': _year}),
          child: const Text('Cetak'),
        ),
      ],
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
