import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/invoice_printer.dart';
import '../../../shared/utils/payment_report_printer.dart';
import '../../../shared/utils/sound_player.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../shared/widgets/transaction_detail_sheet.dart';
import '../../../shared/widgets/status_badge.dart';
import 'rekonsiliasi_setoran_tab.dart';
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
  String? _tempoCabangId;
  int _codMonth = DateTime.now().month;
  int _codYear = DateTime.now().year;
  int _tempoMonth = DateTime.now().month;
  int _tempoYear = DateTime.now().year;
  int _rekonsiliasiMonth = DateTime.now().month;
  int _rekonsiliasiYear = DateTime.now().year;
  int _tabIndex = 0;
  final _dateFmt = DateFormat('MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadCOD();
    _loadTempo();
  }

  List<Map<String, dynamic>> get _codDrivers {
    final seen = <String, Map<String, dynamic>>{};
    for (final t in _codList) {
      if (t.driverUserId == null || t.namaDriver == null) continue;
      final d = seen.putIfAbsent(
        t.driverUserId!,
        () => {
          'id': t.driverUserId!,
          'name': t.namaDriver!,
          'unpaidTotal': 0.0,
          'unpaidCount': 0,
        },
      );
      if (t.statusPembayaran == 'unpaid') {
        d['unpaidTotal'] = (d['unpaidTotal'] as double) + t.biayaKirim;
        d['unpaidCount'] = (d['unpaidCount'] as int) + 1;
      }
    }
    final result = seen.values.toList();
    result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return result;
  }

  List<Map<String, dynamic>> get _tempoCabangs {
    final seen = <String, Map<String, dynamic>>{};
    for (final t in _tempoList) {
      final cabangId = t.createdBy['cabang_id']?.toString();
      final cabangName = t.createdBy['cabang_name']?.toString();
      if (cabangId == null || cabangName == null) continue;
      final c = seen.putIfAbsent(
        cabangId,
        () => {
          'id': cabangId,
          'name': cabangName,
          'unpaidCount': 0,
          'unpaidTotal': 0.0,
        },
      );
      if (t.statusPembayaran == 'unpaid') {
        c['unpaidCount'] = (c['unpaidCount'] as int) + 1;
        c['unpaidTotal'] = (c['unpaidTotal'] as double) + t.biayaKirim;
      }
    }
    final result = seen.values.toList();
    result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
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
      _tempoCabangId = null;
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

    List<Map<String, dynamic>> data;

    if (isCOD) {
      data = list
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
    } else {
      // Tempo: tambah cabang_name & jatuh_tempo, sort unpaid asc → paid asc
      data = list
          .map(
            (t) => {
              'no_resi': t.noResi,
              'pengirim': t.pengirimName,
              'cabang_name': t.createdBy['cabang_name']?.toString() ?? '',
              'biaya_kirim': t.biayaKirim,
              'status_pembayaran': t.statusPembayaran,
              'jatuh_tempo': t.createdAt.add(Duration(days: t.tempoHari)),
            },
          )
          .toList();

      // Sort: unpaid first (by jatuh_tempo asc), then paid (by jatuh_tempo asc)
      data.sort((a, b) {
        final aPaid = a['status_pembayaran'] == 'paid';
        final bPaid = b['status_pembayaran'] == 'paid';
        if (aPaid != bPaid) return aPaid ? 1 : -1;
        final aDate = a['jatuh_tempo'] as DateTime;
        final bDate = b['jatuh_tempo'] as DateTime;
        return aDate.compareTo(bDate);
      });
    }

    final user = ref.read(authProvider).user;
    final isSuperAdmin = user?.role == 'super_admin';
    String? cabangName;
    if (user?.isAdminCabang ?? false) {
      cabangName = list.isNotEmpty
          ? list.first.createdBy['cabang_name']?.toString()
          : null;
    } else if (isSuperAdmin && !isCOD && _tempoCabangId != null) {
      for (final c in _tempoCabangs) {
        if (c['id'] == _tempoCabangId) {
          cabangName = c['name'] as String;
          break;
        }
      }
    }

    await PaymentReportPrinter.printReport(
      month: month,
      year: year,
      data: data,
      jenis: jenis,
      cabangName: cabangName,
    );
  }

  Future<void> _printRekonsiliasiReport({
    required int month,
    required int year,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final list = await repo.getWajibSetor(month: month, year: year);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (list.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada data wajib setor untuk periode ini'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }

      await PaymentReportPrinter.printRekonsiliasiReport(
        month: month,
        year: year,
        data: list,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil data setoran: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _cetakAsli(Transaction tx) async {
    try {
      final user = ref.read(authProvider).user;
      final asal =
          tx.createdBy['cabang_name']?.toString() ??
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal cetak resi: $e')));
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

  Future<void> _cetakTagihan(Transaction tx) async {
    try {
      final user = ref.read(authProvider).user;
      await InvoicePrinter.printInvoice(
        tx,
        dicetakOleh: user?.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cetak tagihan: $e')),
        );
      }
    }
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
      final updated = await repo.confirmPayment(tx.id);
      if (mounted) {
        void updateIn(List<Transaction> list) {
          final i = list.indexWhere((t) => t.id == tx.id);
          if (i != -1) list[i] = updated;
        }
        updateIn(_codList);
        updateIn(_tempoList);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran ${tx.noResi} berhasil dikonfirmasi'),
            backgroundColor: Colors.green,
          ),
        );
        SoundPlayer.instance.playSuccess();
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

  Future<void> _confirmBulkDriver(String driverId) async {
    final targets = _codList
        .where(
          (t) =>
              t.driverUserId == driverId &&
              t.statusPembayaran == 'unpaid',
        )
        .toList();
    if (targets.isEmpty) return;

    final total = targets.fold(0.0, (s, t) => s + t.biayaKirim);
    final driverName = targets.first.namaDriver ?? 'Driver';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Lunas Massal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfirmasi lunas untuk driver $driverName?'),
            const SizedBox(height: 8),
            Text(
              '${targets.length} transaksi \u00b7 ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(total)}',
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
      final ids = targets.map((t) => t.id).toList();
      final res = await repo.confirmPaymentMassal(ids);
      final updated = (res['data'] as List<dynamic>?)
              ?.map(
                (e) => Transaction.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          for (final u in updated) {
            final i = _codList.indexWhere((t) => t.id == u.id);
            if (i != -1) _codList[i] = u;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Berhasil dikonfirmasi'),
            backgroundColor: Colors.green,
          ),
        );
        SoundPlayer.instance.playSuccess();
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
    final isSuperAdmin = role == 'super_admin';
    final showRekonsiliasi = isSuperAdmin;

    final tempoUnpaid =
        _tempoList.where((t) => t.statusPembayaran == 'unpaid').length;

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
          if (_tempoCabangId != null) {
            final cabangId = t.createdBy['cabang_id']?.toString();
            if (cabangId != _tempoCabangId) return false;
          }
          return true;
        }).toList()..sort((a, b) {
          final aPaid = a.statusPembayaran == 'paid';
          final bPaid = b.statusPembayaran == 'paid';
          if (!aPaid && bPaid) return -1;
          if (aPaid && !bPaid) return 1;
          return 0;
        });

    final tabs = <Widget>[];
    final tabViews = <Widget>[];

    if (showRekonsiliasi) {
      tabs.add(const Tab(text: 'Rekonsiliasi Setoran'));
      tabViews.add(
        RekonsiliasiSetoranTab(
          month: _rekonsiliasiMonth,
          year: _rekonsiliasiYear,
        ),
      );
    }

    if (hasCOD) {
      final codUnpaid = _codList.where((t) => t.statusPembayaran == 'unpaid').length;
      tabs.add(
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('COD'),
              if (codUnpaid > 0) ...[
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
                    '$codUnpaid',
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
          hint: 'No. Resi | Nama Penerima',
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
            if (tempoUnpaid > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$tempoUnpaid',
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
        driverFilterId: isSuperAdmin ? _tempoCabangId : null,
        onDriverFilterChanged: isSuperAdmin
            ? (v) => setState(() => _tempoCabangId = v)
            : null,
        drivers: isSuperAdmin ? _tempoCabangs : [],
        driverHintText: 'Semua Cabang',
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
                final isCOD = _tabIndex == (showRekonsiliasi ? 1 : 0) && hasCOD;
                final isRekonsiliasi = showRekonsiliasi && _tabIndex == 0;
                final month = isRekonsiliasi
                    ? _rekonsiliasiMonth
                    : (isCOD ? _codMonth : _tempoMonth);
                final year = isRekonsiliasi
                    ? _rekonsiliasiYear
                    : (isCOD ? _codYear : _tempoYear);
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
                          if (isRekonsiliasi) {
                            setState(() {
                              _rekonsiliasiMonth = result['month']!;
                              _rekonsiliasiYear = result['year']!;
                            });
                          } else if (isCOD) {
                            _setCodMonthYear(result['month']!, result['year']!);
                          } else {
                            _setTempoMonthYear(
                              result['month']!,
                              result['year']!,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                        _dateFmt.format(DateTime(year, month)),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: isRekonsiliasi
                          ? () => _printRekonsiliasiReport(
                              month: month,
                              year: year,
                            )
                          : (list.isEmpty
                                ? null
                                : () => _printReport(
                                    list,
                                    isCOD,
                                    month: month,
                                    year: year,
                                  )),
                      icon: const Icon(Icons.print_rounded, size: 20),
                      color: (isRekonsiliasi || list.isNotEmpty)
                          ? AppTheme.primary
                          : null,
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
    List<Map<String, dynamic>> drivers = const [],
    String driverHintText = 'Semua Driver',
  }) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isDesktop = width >= 1024;
    final crossAxisCount = isDesktop ? 3 : 1;

    final toolbar = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _searchField(search, hint, onSearchChanged),
              const SizedBox(height: 8),
              if (drivers.isNotEmpty)
                _driverDropdown(drivers, driverFilterId, onDriverFilterChanged, hintText: driverHintText),
            ],
          )
        : Row(
            children: [
              Expanded(
                flex: 1,
                child: _searchField(search, hint, onSearchChanged),
              ),
              if (drivers.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _driverDropdown(
                    drivers,
                    driverFilterId,
                    onDriverFilterChanged,
                    hintText: driverHintText,
                  ),
                ),
              ],
            ],
          );

    Map<String, dynamic>? selectedDriver;
    if (isCOD && driverFilterId != null) {
      for (final d in drivers) {
        if (d['id'] == driverFilterId) {
          selectedDriver = d;
          break;
        }
      }
    }

    final unpaidTotal =
        (selectedDriver?['unpaidTotal'] as double?) ?? 0.0;
    final unpaidCount = (selectedDriver?['unpaidCount'] as int?) ?? 0;
    final hasUnpaid = unpaidTotal > 0;

    final banner = (selectedDriver != null)
        ? Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasUnpaid
                  ? () => _confirmBulkDriver(driverFilterId!)
                  : null,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                hasUnpaid
                    ? 'Konfirmasi Lunas ($unpaidCount) - Rp ${Transaction.formatThousands(unpaidTotal)}'
                    : 'Semua Lunas',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasUnpaid ? Colors.green : const Color(0xFF94A3B8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final child = loading
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
                child: crossAxisCount == 1
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) =>
                            _buildTransactionCard(list[i], isCOD, onConfirm),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.6,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) =>
                            _buildTransactionCard(list[i], isCOD, onConfirm),
                      ),
              );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: toolbar,
        ),
        banner,
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _searchField(
    String search,
    String hint,
    ValueChanged<String> onSearchChanged,
  ) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 4),
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
        suffixIcon: search.isNotEmpty
            ? GestureDetector(
                onTap: () => onSearchChanged(''),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.clear, size: 20),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onChanged: onSearchChanged,
    );
  }

  Widget _driverDropdown(
    List<Map<String, dynamic>> drivers,
    String? driverFilterId,
    ValueChanged<String?>? onDriverFilterChanged, {
    String hintText = 'Semua Driver',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: driverFilterId,
          hint: Text(
            hintText,
            style: TextStyle(fontSize: 13),
          ),
          isExpanded: true,
          icon: const Icon(Icons.filter_list_rounded, size: 20),
          borderRadius: BorderRadius.circular(10),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                hintText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            ...drivers.map(
              (d) => DropdownMenuItem<String>(
                value: d['id'] as String,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d['name'] as String,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if ((d['unpaidTotal'] as double) > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Rp ${Transaction.formatThousands(d['unpaidTotal'] as double)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF57F17),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          onChanged: onDriverFilterChanged,
        ),
      ),
    );
  }

  Widget _tempoBadge(Transaction tx) {
    if (tx.statusPembayaran == 'paid') {
      final tanggal = tx.pembayaranDikonfirmasiPada;
      final fmt = DateFormat('d MMM yyyy', 'id_ID');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 12,
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(width: 4),
            Text(
              tanggal != null ? '${fmt.format(tanggal)}' : 'Lunas',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      );
    }

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
            lewat ? '${-sisaHari}h lalu' : '$sisaHari hari lagi',
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
    final isAdminCabang =
        ref.read(authProvider).user?.role == 'admin_cabang';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          final user = ref.read(authProvider).user;
          TransactionDetailSheet.show(
            context,
            tx: tx,
            isAdminCabang: user?.isAdminCabang ?? false,
            currentCabangId: user?.cabangId,
            onCetakAsli: () => _cetakAsli(tx),
            onCetakRetur: () => _cetakRetur(tx),
          );
        },
        borderRadius: BorderRadius.circular(10),
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
                        StatusBadge(status: tx.statusSaatIni, fontSize: 10),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isCOD
                                ? 'Penerima: ${tx.penerimaName}'
                                : '${tx.pengirimName} \u2192 ${tx.penerimaName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCOD && tx.jenisMasalah == 'gagal_kirim')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Retur',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
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
                        if (isCOD) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'COD',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF57F17),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tx.statusPembayaran == 'paid'
                                  ? const Color(0xFFE8F5E9)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tx.statusPembayaran == 'paid'
                                  ? 'Lunas'
                                  : 'Belum Lunas',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: tx.statusPembayaran == 'paid'
                                    ? const Color(0xFF2E7D32)
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ] else ...[
                          _tempoBadge(tx),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tx.statusPembayaran == 'paid'
                                  ? const Color(0xFFE8F5E9)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tx.statusPembayaran == 'paid'
                                  ? 'Lunas'
                                  : 'Belum Lunas',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: tx.statusPembayaran == 'paid'
                                    ? const Color(0xFF2E7D32)
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
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
                    Row(
                      children: [
                        if (!isCOD) ...[
                          if (isAdminCabang)
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton(
                                  onPressed: () => _cetakTagihan(tx),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE8F5E9),
                                    side: const BorderSide(
                                      color: Color(0xFFA5D6A7),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 18,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  onPressed: () => _cetakTagihan(tx),
                                  icon: const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 16,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  label: const Text(
                                    'Cetak Tagihan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE8F5E9),
                                    side: const BorderSide(
                                      color: Color(0xFFA5D6A7),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (isCOD || isAdminCabang)
                            const SizedBox(width: 8),
                        ],
                        if (isCOD || isAdminCabang)
                          Expanded(
                            flex: (!isCOD && isAdminCabang) ? 8 : 1,
                            child: SizedBox(
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
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      title: const Text('Pilih Bulan \u0026 Tahun'),
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
