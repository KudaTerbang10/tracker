import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/utils/payment_report_printer.dart';
import '../../../shared/utils/sound_player.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class PaymentManagementScreen extends ConsumerStatefulWidget {
  const PaymentManagementScreen({super.key});
  @override
  ConsumerState<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState
    extends ConsumerState<PaymentManagementScreen> {
  List<Transaction> _codList = [];
  List<Transaction> _tempoList = [];
  bool _codLoading = true;
  bool _tempoLoading = true;
  String _codSearch = '';
  String _tempoSearch = '';
  String? _codDriverId;
  int _codMonth = DateTime.now().month;
  int _codYear = DateTime.now().year;
  int _tempoMonth = DateTime.now().month;
  int _tempoYear = DateTime.now().year;
  int _tabIndex = 0;
  final _dateFmt = DateFormat('MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadCOD();
    _loadTempo();
  }

  List<Map<String, String>> get _codDrivers {
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final t in _codList) {
      if (t.driverUserId != null &&
          t.namaDriver != null &&
          seen.add(t.driverUserId!)) {
        result.add({'id': t.driverUserId!, 'name': t.namaDriver!});
      }
    }
    result.sort((a, b) => a['name']!.compareTo(b['name']!));
    return result;
  }

  void _setCodMonthYear(int month, int year) {
    setState(() {
      _codMonth = month;
      _codYear = year;
      _codLoading = true;
    });
    _loadCOD();
  }

  void _setTempoMonthYear(int month, int year) {
    setState(() {
      _tempoMonth = month;
      _tempoYear = year;
      _tempoLoading = true;
    });
    _loadTempo();
  }

  Future<void> _loadCOD() async {
    final user = ref.read(authProvider).user;
    if (user == null || user.role != 'admin_cabang') {
      setState(() => _codLoading = false);
      return;
    }
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final list = await repo.getPaymentByMonth(
        jenisPembayaran: 'cod',
        month: _codMonth,
        year: _codYear,
      );
      if (mounted) {
        setState(() {
          _codList = list;
          _codLoading = false;
          _codDriverId = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _codLoading = false);
    }
  }

  Future<void> _loadTempo() async {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final list = await repo.getPaymentByMonth(
        jenisPembayaran: 'tempo',
        month: _tempoMonth,
        year: _tempoYear,
      );
      if (mounted) {
        setState(() {
          _tempoList = list;
          _tempoLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tempoLoading = false);
    }
  }

  Future<void> _printReport(
    List<Transaction> list,
    bool isCOD, {
    required int month,
    required int year,
  }) async {
    final jenis = isCOD ? 'cod' : 'tempo';
    final data = list
        .map(
          (t) => {
            'no_resi': t.noResi,
            'pengirim': t.pengirimName,
            'penerima': t.penerimaName,
            'biaya_kirim': t.biayaKirim,
            'status_pembayaran': t.statusPembayaran,
          },
        )
        .toList();

    final user = ref.read(authProvider).user;
    String? cabangName;
    if (user?.isAdminCabang ?? false) {
      cabangName = list.isNotEmpty
          ? list.first.createdBy['cabang_name']?.toString()
          : null;
    }

    await PaymentReportPrinter.printReport(
      month: month,
      year: year,
      data: data,
      jenis: jenis,
      cabangName: cabangName,
    );
  }

  Future<void> _confirmPayment(Transaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfirmasi pembayaran untuk resi ${tx.noResi}?'),
            if (tx.jenisPembayaran == 'cod')
              Text(
                'Penerima: ${tx.penerimaName}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            Text(
              'Biaya: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(tx.biayaKirim)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Konfirmasi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.confirmPayment(tx.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran ${tx.noResi} berhasil dikonfirmasi'),
            backgroundColor: Colors.green,
          ),
        );
        SoundPlayer.instance.playSuccess();
        _loadCOD();
        _loadTempo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengkonfirmasi pembayaran'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final role = user?.role ?? '';
    final hasCOD = role == 'admin_cabang';

    List<Transaction> filteredCod =
        _codList.where((t) {
          if (_codSearch.isNotEmpty) {
            final matchResi = t.noResi.toLowerCase().contains(
              _codSearch.toLowerCase(),
            );
            final matchNama = t.penerimaName.toLowerCase().contains(
              _codSearch.toLowerCase(),
            );
            if (!matchResi && !matchNama) return false;
          }
          if (_codDriverId != null && t.driverUserId != _codDriverId)
            return false;
          return true;
        }).toList()..sort((a, b) {
          if (a.statusPembayaran == 'unpaid' && b.statusPembayaran != 'unpaid')
            return -1;
          if (a.statusPembayaran != 'unpaid' && b.statusPembayaran == 'unpaid')
            return 1;
          return 0;
        });

    List<Transaction> filteredTempo =
        _tempoList.where((t) {
          if (_tempoSearch.isNotEmpty) {
            final matchResi = t.noResi.toLowerCase().contains(
              _tempoSearch.toLowerCase(),
            );
            final matchNama = t.penerimaName.toLowerCase().contains(
              _tempoSearch.toLowerCase(),
            );
            final matchPengirim = t.pengirimName.toLowerCase().contains(
              _tempoSearch.toLowerCase(),
            );
            if (!matchResi && !matchNama && !matchPengirim) return false;
          }
          return true;
        }).toList()..sort((a, b) {
          if (a.statusPembayaran == 'unpaid' && b.statusPembayaran != 'unpaid')
            return -1;
          if (a.statusPembayaran != 'unpaid' && b.statusPembayaran == 'unpaid')
            return 1;
          return 0;
        });

    final tabs = <Widget>[];
    final tabViews = <Widget>[];

    if (hasCOD) {
      tabs.add(
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('COD'),
              if (_codList.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_codList.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF57F17),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      tabViews.add(
        _buildTab(
          search: _codSearch,
          onSearchChanged: (v) => setState(() => _codSearch = v),
          loading: _codLoading,
          list: filteredCod,
          onRefresh: _loadCOD,
          onConfirm: _confirmPayment,
          hint: 'No. Resi atau Nama Penerima',
          emptyText: 'Tidak ada transaksi COD yang belum lunas',
          isCOD: true,
          driverFilterId: _codDriverId,
          onDriverFilterChanged: (v) => setState(() => _codDriverId = v),
          drivers: _codDrivers,
        ),
      );
    }

    tabs.add(
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tempo'),
            if (_tempoList.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_tempoList.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    tabViews.add(
      _buildTab(
        search: _tempoSearch,
        onSearchChanged: (v) => setState(() => _tempoSearch = v),
        loading: _tempoLoading,
        list: filteredTempo,
        onRefresh: _loadTempo,
        onConfirm: _confirmPayment,
        hint: 'Cari no resi, nama pengirim, atau penerima...',
        emptyText: 'Tidak ada transaksi Tempo yang belum lunas',
        isCOD: false,
      ),
    );

    return DefaultTabController(
      length: tabs.length,
      initialIndex: hasCOD ? 0 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Pembayaran'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            Builder(
              builder: (ctx) {
                final isCOD = _tabIndex == 0 && hasCOD;
                final month = isCOD ? _codMonth : _tempoMonth;
                final year = isCOD ? _codYear : _tempoYear;
                final list = isCOD ? filteredCod : filteredTempo;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final result = await showDialog<Map<String, int>>(
                          context: context,
                          builder: (ctx) => _MonthYearPickerDialog(
                            initialMonth: month,
                            initialYear: year,
                          ),
                        );
                        if (result != null && mounted) {
                          if (isCOD) {
                            _setCodMonthYear(
                              result['month']!,
                              result['year']!,
                            );
                          } else {
                            _setTempoMonthYear(
                              result['month']!,
                              result['year']!,
                            );
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _dateFmt.format(DateTime(year, month)),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: list.isEmpty
                          ? null
                          : () => _printReport(
                              list,
                              isCOD,
                              month: month,
                              year: year,
                            ),
                      icon: const Icon(Icons.print_rounded, size: 20),
                      color: list.isEmpty ? null : AppTheme.primary,
                      tooltip: 'Cetak Laporan',
                    ),
                  ],
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: tabs,
            onTap: (i) => setState(() => _tabIndex = i),
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }

  Widget _buildTab({
    required String search,
    required ValueChanged<String> onSearchChanged,
    required bool loading,
    required List<Transaction> list,
    required VoidCallback onRefresh,
    required void Function(Transaction) onConfirm,
    required String hint,
    required String emptyText,
    required bool isCOD,
    String? driverFilterId,
    ValueChanged<String?>? onDriverFilterChanged,
    List<Map<String, String>> drivers = const [],
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (search.isNotEmpty)
                          GestureDetector(
                            onTap: () => onSearchChanged(''),
                            child: const Icon(Icons.clear, size: 20),
                          ),
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                            onPressed: () async {
                              final code = await BarcodeScannerDialog.show(
                                context,
                                label: 'Scan resi',
                              );
                              if (code != null && code.isNotEmpty) {
                                onSearchChanged(code);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    suffixIconConstraints: const BoxConstraints(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              if (drivers.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: driverFilterId,
                        hint: const Text(
                          'Semua Driver',
                          style: TextStyle(fontSize: 13),
                        ),
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list_rounded, size: 20),
                        borderRadius: BorderRadius.circular(10),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'Semua Driver',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          ...drivers.map(
                            (d) => DropdownMenuItem<String>(
                              value: d['id'],
                              child: Text(
                                d['name']!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                        onChanged: onDriverFilterChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                loading ? 'Memuat...' : '${list.length} transaksi',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRefresh,
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
              ? Center(
                  child: Text(
                    emptyText,
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => onRefresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final tx = list[i];
                      return _buildTransactionCard(tx, isCOD, onConfirm);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tempoBadge(Transaction tx) {
    final jatuhTempo = tx.createdAt.add(Duration(days: tx.tempoHari));
    final now = DateTime.now();
    final sisaHari = jatuhTempo.difference(now).inDays;
    final lewat = sisaHari < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: lewat
            ? Colors.red.withValues(alpha: 0.1)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lewat ? Icons.warning_amber_rounded : Icons.access_time_rounded,
            size: 12,
            color: lewat ? Colors.red : const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 4),
          Text(
            lewat ? 'Tempo ${-sisaHari}h lalu' : '  Tempo $sisaHari hari lagi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: lewat ? Colors.red : const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    Transaction tx,
    bool isCOD,
    void Function(Transaction) onConfirm,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCOD
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.payments_rounded,
                color: isCOD
                    ? const Color(0xFFF57F17)
                    : const Color(0xFF2E7D32),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.noResi,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (isCOD)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tx.jenisMasalah == 'gagal_kirim') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Retur',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tx.statusPembayaran == 'paid'
                                    ? const Color(0xFFE8F5E9)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tx.statusPembayaran == 'paid' ? 'Lunas' : 'Belum Lunas',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: tx.statusPembayaran == 'paid' ? const Color(0xFF2E7D32) : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tx.statusPembayaran == 'paid'
                                ? const Color(0xFFE8F5E9)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.statusPembayaran == 'paid' ? 'Lunas' : 'Belum Lunas',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: tx.statusPembayaran == 'paid' ? const Color(0xFF2E7D32) : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isCOD
                              ? 'Penerima: ${tx.penerimaName}'
                              : '${tx.pengirimName} → ${tx.penerimaName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCOD)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'COD',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF57F17)),
                          ),
                        )
                      else
                        _tempoBadge(tx),
                    ],
                  ),
                  if (isCOD && tx.namaDriver != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Driver: ${tx.namaDriver}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isCOD
                              ? tx.penerimaAddress
                              : '${tx.penerima['kota'] ?? ''}, ${tx.penerima['kecamatan'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(tx.biayaKirim),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (!isCOD && tx.createdBy['cabang_name'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cabang asal: ${tx.createdBy['cabang_name']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: tx.statusPembayaran == 'paid'
                          ? null
                          : () => onConfirm(tx),
                      icon: Icon(
                        tx.statusPembayaran == 'paid'
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        size: 16,
                      ),
                      label: Text(
                        tx.statusPembayaran == 'paid'
                            ? 'Sudah Lunas'
                            : 'Konfirmasi Lunas',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tx.statusPembayaran == 'paid'
                            ? const Color(0xFF94A3B8)
                            : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  const _MonthYearPickerDialog({
    required this.initialMonth,
    required this.initialYear,
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
      title: const Text('Pilih Bulan & Tahun'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              const perRow = 3;
              final rows = <List<int>>[];
              for (var i = 0; i < 12; i += perRow) {
                rows.add(
                  List.generate(
                    (i + perRow > 12 ? 12 - i : perRow),
                    (j) => i + j,
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: rows.map((rowIndices) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: rowIndices.map((i) {
                        final m = i + 1;
                        final selected = _month == m;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _month = m),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                _months[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: years.contains(_year - 1)
                    ? () => setState(() => _year--)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_year',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: years.contains(_year + 1)
                    ? () => setState(() => _year++)
                    : null,
              ),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop({'month': _month, 'year': _year}),
                child: const Text('Lihat'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
