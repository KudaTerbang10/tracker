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
import '../../../shared/widgets/transaction_detail_sheet.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/sound_player.dart';
import '../../../shared/utils/branch_report_printer.dart';
import '../../../shared/utils/driver_report_printer.dart';
import '../../../shared/utils/driver_performance_printer.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/constants/api_constants.dart';

final _prosesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref
      .read(transactionRepositoryProvider)
      .getList(tab: 'current', limit: 999);
});

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});
  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool get _isAdminCabang =>
      ref.read(authProvider).user?.isAdminCabang ?? false;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = '';

  // Infinite scroll untuk history tab (transaction-based)
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
        if (_historyScrollC.position.pixels >=
            _historyScrollC.position.maxScrollExtent - 200) {
          _loadHistory();
        }
      });
    } else {
      _superAdminScrollC.addListener(() {
        if (_superAdminScrollC.position.pixels >=
            _superAdminScrollC.position.maxScrollExtent - 200) {
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
        label: type == 'driver_antar_cabang'
            ? 'Laporan Driver Antar Cabang'
            : type == 'driver_antar_penerima'
                ? 'Laporan Driver ke Penerima'
                : 'Laporan Per Cabang',
      ),
    );

    if (result == null || !mounted) return;
    _generateReport(type: type, month: result['month']!, year: result['year']!);
  }

  Future<void> _generateReport({
    required String type,
    required int month,
    required int year,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final repo = ref.read(transactionRepositoryProvider);
      final List<Map<String, dynamic>> data;
      final bool isDriverPerf =
          type == 'driver_antar_cabang' || type == 'driver_antar_penerima';

      if (isDriverPerf) {
        final result =
            await repo.getDriverPerformance(month: month, year: year);
        final tipeKey =
            type == 'driver_antar_cabang' ? 'antar_cabang' : 'antar_penerima';
        final list = (result[tipeKey] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        data = list;
      } else if (type == 'driver') {
        data = await repo.getDriverReport(month: month, year: year);
      } else {
        data = await repo.getPerCabangReport(month: month, year: year);
      }

      if (mounted) Navigator.of(context).pop();

      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data untuk bulan yang dipilih'),
          ),
        );
        return;
      }

      if (isDriverPerf) {
        final tipeKey =
            type == 'driver_antar_cabang' ? 'antar_cabang' : 'antar_penerima';
        await DriverPerformancePrinter.printReport(
          month: month,
          year: year,
          data: data,
          type: tipeKey,
        );
      } else if (type == 'driver') {
        await DriverReportPrinter.printReport(
          month: month,
          year: year,
          data: data,
        );
      } else {
        await BranchReportPrinter.printReport(
          month: month,
          year: year,
          data: data,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil data: $e')));
    }
  }

  Future<void> _loadSuperAdmin() async {
    if (_superAdminLoadingMore || _superAdminPage > _superAdminTotalPages)
      return;
    if (_superAdminPage == 1) _superAdminItems.clear();
    _superAdminLoadingMore = true;
    try {
      final result = await ref
          .read(transactionRepositoryProvider)
          .getList(
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
      final result = await ref
          .read(transactionRepositoryProvider)
          .getList(
            tab: 'history',
            page: _historyPage,
            limit: 20,
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
    _historyLoadingMore = false;
    _loadHistory();
  }

  Future<void> _scanAndSearch() async {
    final code = await BarcodeScannerDialog.show(
      context,
      label: 'Scan barcode untuk mencari transaksi',
    );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isAdminCabang)
            PopupMenuButton<String>(
              icon: const Icon(Icons.print_rounded, color: Colors.indigo),
              tooltip: 'Cetak Laporan',
              surfaceTintColor: Colors.transparent,
              color: Colors.white,
              onSelected: (v) => _showMonthYearPicker(v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'cabang',
                  child: Row(
                    children: [
                      Icon(Icons.store, size: 18, color: Colors.indigoAccent),
                      SizedBox(width: 10),
                      Text('Laporan Per Cabang'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'driver_antar_cabang',
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping, size: 18, color: Colors.indigoAccent),
                      SizedBox(width: 10),
                      Text('Laporan Driver Antar Cabang'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'driver_antar_penerima',
                  child: Row(
                    children: [
                      Icon(Icons.person_pin_circle, size: 18, color: Colors.indigoAccent),
                      SizedBox(width: 10),
                      Text('Laporan Driver ke Penerima'),
                    ],
                  ),
                ),
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
              children: [_buildProsesTab(dateFmt), _buildHistoryTab(dateFmt)],
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 12,
              ),
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
            Text(
              'Tidak ada transaksi',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _superAdminScrollC,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount:
          _superAdminItems.length +
          (_superAdminPage <= _superAdminTotalPages ? 1 : 0),
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
                Text(
                  'Belum ada transaksi proses',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: list.length,
          itemBuilder: (_, i) =>
              _buildItemCard(list[i], dateFmt, canDelete: true),
        );
      },
    );
  }

  Widget _buildHistoryTab(DateFormat dateFmt) {
    final fmt = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        // Date filter bar
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
                        if (states.contains(WidgetState.selected))
                          return const Color(0xFF6366F1);
                        return Colors.transparent;
                      }),
                      dayForegroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected))
                          return Colors.white;
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
                          : 'Filter berdasarkan tanggal',
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
                          _resetHistory();
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
        // Transaction list
        Expanded(
          child: _historyItems.isEmpty && !_historyLoadingMore
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada riwayat transaksi',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _resetHistory();
                  },
                  child: ListView.builder(
                    controller: _historyScrollC,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount:
                        _historyItems.length +
                        (_historyPage <= _historyTotalPages ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _historyItems.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return _buildItemCard(
                        _historyItems[i],
                        dateFmt,
                        canDelete: false,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildItemCard(
    Transaction tx,
    DateFormat dateFmt, {
    required bool canDelete,
  }) {
    final user = ref.read(authProvider).user;
    final isDriver = user?.isDriver ?? false;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showDetail(tx),
        onLongPress: canDelete && _canDelete(tx, user)
            ? () => _confirmDelete(tx)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Resi number + COD/Tempo badge + Copy/Print
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tx.noResi,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                        fontSize: 11,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tx.jenisPembayaran == 'cod' || tx.jenisPembayaran == 'tempo') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tx.jenisPembayaran == 'cod'
                            ? const Color(0xFFFFF8E1)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: tx.jenisPembayaran == 'cod'
                              ? const Color(0xFFFFE082)
                              : const Color(0xFFA5D6A7),
                        ),
                      ),
                      child: Text(
                        tx.jenisPembayaran == 'cod' ? 'COD' : 'Tempo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tx.jenisPembayaran == 'cod'
                              ? const Color(0xFFF57F17)
                              : const Color(0xFF2E7D32),
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (tx.jenisMasalah == 'gagal_kirim' &&
                      (tx.statusSaatIni == 'diterima_cabang' ||
                          tx.statusSaatIni == 'keluar_cabang'))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => _serahTerimaRetur(tx),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.how_to_reg_rounded,
                            size: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ResiCopyButton(resi: tx.noResi),
                  if (!isDriver) ...[
                    const SizedBox(width: 8),
                    if (tx.statusSaatIni == 'gagal_kirim' ||
                        tx.jenisMasalah == 'gagal_kirim')
                      PopupMenuButton<String>(
                        tooltip: 'Cetak',
                        color: Colors.white,
                        surfaceTintColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        onSelected: (value) {
                          if (value == 'asli') {
                            _cetakAsli(tx);
                          } else {
                            _cetakRetur(tx);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'asli',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.print_rounded,
                                  size: 18,
                                  color: Color(0xFF3B82F6),
                                ),
                                SizedBox(width: 10),
                                Text('Cetak Asli'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'retur',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 18,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 10),
                                const Text('Cetak Resi Retur'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.print,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => _cetakAsli(tx),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.print,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Second row: pengirim → penerima
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            tx.pengirimName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            tx.penerimaName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                dateFmt.format(toJakarta(tx.createdAt)),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 2),
              // Third row: badges
              Row(
                children: [
                  StatusBadge(status: tx.statusSaatIni),
                  if (tx.jenisMasalah == 'gagal_kirim') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.replay,
                            size: 12,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Barang Retur',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Transaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text(
          'Transaksi dengan No. Resi ${tx.noResi} akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  bool _canDelete(Transaction tx, User? user) {
    if (user == null) return false;
    if (!user.isAdminCabang) return false;
    if (tx.statusSaatIni != 'diterima_cabang') return false;
    if (tx.trackingLogs.isNotEmpty) {
      final firstCabang = tx.trackingLogs.first.lokasi?['cabang_id']
          ?.toString();
      if (firstCabang != null) return firstCabang == user.cabangId;
    }
    return tx.trackingLogs.length == 1;
  }

  Future<void> _cetakAsli(Transaction tx) async {
    try {
      final user = ref.read(authProvider).user;
      final asal = tx.createdBy['cabang_name']?.toString() ??
          tx.createdBy['konter_name']?.toString() ??
          tx.createdBy['gudang_name']?.toString();
      await LabelPrinter.printBarcodeLabel(
        data: tx.noResi,
        pengirim: tx.pengirim,
        penerima: tx.penerima,
        paket: tx.paket,
        createdAt: tx.createdAt,
        asal: asal,
        dicetakOleh: user?.lokasi?['name']?.toString(),
        isCOD: tx.jenisPembayaran == 'cod',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cetak resi: $e')),
        );
      }
    }
  }

  Future<void> _cetakRetur(Transaction tx) async {
    try {
      final user = ref.read(authProvider).user;
      final cabangRetur = {
        'name': user?.lokasi?['name']?.toString() ?? 'Cabang',
        'phone': user?.lokasi?['phone']?.toString() ?? '',
        'address': '',
      };
      final asalCabang = tx.createdBy['cabang_name']?.toString() ?? '';
      await LabelPrinter.printReturLabel(
        data: tx.noResi,
        penerima: tx.pengirim,
        pengirim: cabangRetur,
        paket: tx.paket,
        createdAt: tx.createdAt,
        dicetakOleh: user?.lokasi?['name']?.toString(),
        asalCabang: asalCabang,
        isCOD: tx.jenisPembayaran == 'cod',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal cetak retur: $e')));
      }
    }
  }

  Future<void> _serahTerimaRetur(Transaction tx) async {
    if (tx.jenisPembayaran == 'cod' && tx.statusPembayaran == 'unpaid') {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 40,
          ),
          title: const Text('Pembayaran COD'),
          content: const Text(
            'Pembayaran COD transaksi ini belum dibayar, pastikan pembayaran sudah lunas!',
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Konfirmasi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Serah Terima Barang Retur?'),
        content: Text(
          'Resi ${tx.noResi} akan ditandai sebagai "Diterima" (pengirim telah mengambil barang).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Serah Terima', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.batchUpdateStatus(
        noResiList: [tx.noResi],
        statusBaru: 'diterima',
        catatan: 'Barang retur diambil langsung oleh pengirim di cabang',
      );
      ref.invalidate(_prosesProvider);
      SoundPlayer.instance.playSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tx.noResi} selesai serah terima'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showDetail(Transaction tx) {
    final user = ref.read(authProvider).user;
    final isDriver = user?.isDriver ?? false;
    final isAdminCabang = user?.isAdminCabang ?? false;

    TransactionDetailSheet.show(
      context,
      tx: tx,
      isDriver: isDriver,
      isAdminCabang: isAdminCabang,
      currentCabangId: user?.cabangId,
      onCetakAsli: () => _cetakAsli(tx),
      onCetakRetur: () => _cetakRetur(tx),
      onLaporkanHilang: () => _laporkanHilang(tx),
      onSerahTerimaRetur: () => _serahTerimaRetur(tx),
    );
  }

  Future<void> _laporkanHilang(Transaction tx) async {
    final resiText = tx.noResi;
    final jenis = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Laporkan Masalah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Resi: $resiText'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.red),
              title: const Text('Barang Hilang'),
              subtitle: const Text('Paket tidak ditemukan saat verifikasi'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () => Navigator.of(ctx).pop('hilang'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.orange),
              title: const Text('Gagal Kirim'),
              subtitle: const Text(
                'Paket tidak dapat dikirim, retur ke pengirim',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () => Navigator.of(ctx).pop('gagal_kirim'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (jenis == null) return;

    final catatanC = TextEditingController();
    final catatan = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${jenis == 'hilang' ? 'Barang Hilang' : 'Gagal Kirim'} — Catatan',
        ),
        content: TextField(
          controller: catatanC,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              if (newValue.text.isEmpty) return newValue;
              final capitalized = newValue.text
                  .split(' ')
                  .map((word) {
                    if (word.isEmpty) return word;
                    return word[0].toUpperCase() + word.substring(1);
                  })
                  .join(' ');
              return TextEditingValue(
                text: capitalized,
                selection: TextSelection.collapsed(offset: capitalized.length),
              );
            }),
          ],
          decoration: const InputDecoration(
            hintText: 'Deskripsi / kronologi kejadian...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () {
              catatanC.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final v = catatanC.text.trim();
              catatanC.dispose();
              Navigator.of(ctx).pop(v.isEmpty ? null : v);
            },
            icon: const Icon(Icons.warning_amber_rounded, size: 18),
            label: const Text('Laporkan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
    if (catatan == null) return;

    try {
      await ref
          .read(transactionRepositoryProvider)
          .laporkanMasalah(id: tx.id, jenis: jenis, catatan: catatan);
      ref.invalidate(_prosesProvider);
      SoundPlayer.instance.playScan();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Resi $resiText berhasil dilaporkan sebagai ${jenis == 'hilang' ? 'Barang Hilang' : 'Gagal Kirim'}',
            ),
            backgroundColor: jenis == 'hilang' ? Colors.red : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
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
          onPressed: () =>
              Navigator.of(context).pop({'month': _month, 'year': _year}),
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
