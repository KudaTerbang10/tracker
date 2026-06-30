import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/sound_player.dart';
import '../../../shared/utils/problematic_report_printer.dart';

class ProblematicTransactionsScreen extends ConsumerStatefulWidget {
  const ProblematicTransactionsScreen({super.key});

  @override
  ConsumerState<ProblematicTransactionsScreen> createState() =>
      _ProblematicTransactionsScreenState();
}

class _ProblematicTransactionsScreenState
    extends ConsumerState<ProblematicTransactionsScreen> {
  final _resiManualC = TextEditingController();
  bool _loading = false;
  String _filter = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final _dateFmt = DateFormat('MMMM yyyy', 'id_ID');
  List<Transaction>? _cachedBermasalah;

  @override
  void dispose() {
    _resiManualC.dispose();
    super.dispose();
  }

  bool get _isSuperAdmin => ref.read(authProvider).user?.isSuperAdmin ?? false;

  Future<List<Transaction>> _loadBermasalah() async {
    final repo = ref.read(transactionRepositoryProvider);
    final startDate = DateTime(_selectedYear, _selectedMonth, 1);
    final endDate = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final result = await repo.getList(
      tab: 'bermasalah',
      limit: 999,
      startDate: startDate,
      endDate: endDate,
    );
    return result['data'] as List<Transaction>;
  }

  Future<void> _tandaiSelesai(Transaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai Selesai?'),
        content: Text(
          'Kasus ${tx.noResi} akan ditandai selesai. '
          'Pastikan penyelesaian hak konsumen sudah dilakukan.',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tandai Selesai', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(transactionRepositoryProvider).tandaiSelesai(tx.id);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tx.noResi} telah ditandai selesai')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
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
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal cetak retur: $e')));
      }
    }
  }

  Future<void> _batalkanHilang(Transaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Barang Ditemukan?'),
        content: Text(
          'Status ${tx.noResi} akan dikembalikan ke "Diterima Cabang" '
          'dan muncul kembali di daftar transaksi cabang pelapor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Ditemukan', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final api = ApiService();
      await api.post('${ApiConstants.transactions}/${tx.id}/batalkan-hilang');
      SoundPlayer.instance.playSuccess();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tx.noResi} dikembalikan ke proses'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  void _showDetail(Transaction tx) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final showDriver = tx.namaDriver != null;
    final pelapor = tx.dilaporkanOleh?['name'] as String? ?? '-';
    final cabangNama = tx.dilaporkanOleh?['cabang_name'] as String? ?? '-';
    final dateFmt = DateFormat('dd/MM/yy HH:mm', 'id_ID');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, scrollC) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFCBD5E1),
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

                    // Sender & Recipient
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _DetailInfoCard(
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
                            child: _DetailInfoCard(
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

                    // Specs
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
                              child: _DetailInfoCell(
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
                              child: _DetailInfoCell(
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
                                child: _DetailInfoCell(
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

                    // Problem info
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  tx.jenisMasalah == 'hilang'
                                      ? Icons.report_problem_rounded
                                      : Icons.cancel_outlined,
                                  size: 16,
                                  color: tx.jenisMasalah == 'hilang'
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tx.jenisMasalah == 'hilang'
                                      ? 'BARANG HILANG'
                                      : 'GAGAL KIRIM',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: tx.jenisMasalah == 'hilang'
                                        ? Colors.red
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dilaporkan oleh: $pelapor ($cabangNama)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                            if (tx.dilaporkanPada != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Pada: ${dateFmt.format(tx.dilaporkanPada!.toLocal())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                            if (tx.catatanMasalah != null &&
                                tx.catatanMasalah!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tx.jenisMasalah == 'hilang'
                                      ? Colors.red.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Catatan: ${tx.catatanMasalah}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tx.jenisMasalah == 'hilang'
                                        ? Colors.red.shade800
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                            if (tx.statusSaatIni == 'kasus_selesai' &&
                                tx.diselesaikanOleh != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Diselesaikan oleh ${tx.diselesaikanOleh!['name']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Driver info
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
                                child: _DetailInfoCard(
                                  title: 'Driver',
                                  name: tx.namaDriver!,
                                  phone: tx.kontakDriver ?? '',
                                  address: '',
                                  icon: Icons.directions_car_filled_rounded,
                                  accentColor: Colors.amber.shade700,
                                ),
                              ),
                            if (showDriver &&
                                tx.namaPenerimaAkhir != null &&
                                tx.namaPenerimaAkhir!.isNotEmpty)
                              const SizedBox(width: 8),
                            if (tx.namaPenerimaAkhir != null &&
                                tx.namaPenerimaAkhir!.isNotEmpty)
                              Expanded(
                                child: _DetailInfoCard(
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

  Future<void> _laporkanManual() async {
    final noResi = _resiManualC.text.trim().toUpperCase();
    if (noResi.isEmpty) return;

    final jenis = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Laporkan Masalah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Resi: $noResi'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.red),
              title: const Text('Barang Hilang'),
              onTap: () => Navigator.of(ctx).pop('hilang'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.orange),
              title: const Text('Gagal Kirim (Retur)'),
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
          'Catatan ${jenis == 'hilang' ? 'Barang Hilang' : 'Gagal Kirim'}',
        ),
        content: TextField(
          controller: catatanC,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [_CapitalizeWordsFormatter()],
          decoration: const InputDecoration(
            hintText: 'Deskripsi singkat...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              catatanC.dispose();
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
      _loading = true;
      setState(() {});
      // Cari resi dari SELURUH transaksi via track API (tanpa filter cabang)
      final res = await ApiService().get('${ApiConstants.track}/$noResi');
      final tx = Transaction.fromJson(res.data as Map<String, dynamic>);
      final repo = ref.read(transactionRepositoryProvider);
      await repo.laporkanMasalah(id: tx.id, jenis: jenis, catatan: catatan);
      _resiManualC.clear();
      _loading = false;
      setState(() {});
      SoundPlayer.instance.playScan();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(
              jenis == 'hilang'
                  ? Icons.report_problem_rounded
                  : Icons.cancel_rounded,
              color: jenis == 'hilang' ? Colors.red : Colors.orange,
              size: 40,
            ),
            title: Text(
              jenis == 'hilang'
                  ? 'Dilaporkan Hilang'
                  : 'Dilaporkan Gagal Kirim',
            ),
            content: Text('Resi $noResi berhasil dilaporkan.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _loading = false;
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _printReport(String jenis) async {
    try {
      final list = _cachedBermasalah;
      if (list == null || list.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data untuk dicetak')),
          );
        }
        return;
      }
      final filtered = list.where((tx) => tx.jenisMasalah == jenis).toList();
      final data = filtered.map((tx) {
        final pelapor = tx.dilaporkanOleh as Map<String, dynamic>?;
        return {
          'no_resi': tx.noResi,
          'jenis_masalah': tx.jenisMasalah ?? '',
          'pengirim': tx.pengirimName,
          'penerima': tx.penerimaName,
          'pelapor': pelapor?['name'] as String? ?? '-',
          'cabang': pelapor?['cabang_name'] as String? ?? '-',
          'dilaporkan_pada': tx.dilaporkanPada?.toIso8601String(),
          'status': tx.statusSaatIni,
          'catatan': tx.catatanMasalah ?? '-',
        };
      }).toList();

      await ProblematicReportPrinter.printReport(
        month: _selectedMonth,
        year: _selectedYear,
        data: data,
        jenis: jenis,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cetak laporan: $e')),
        );
      }
    }
  }

  Future<void> _scanResi() async {
    final code = await BarcodeScannerDialog.show(
      context,
      label: 'Scan resi yang bermasalah',
    );
    if (code != null && code.isNotEmpty) {
      _resiManualC.text = code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yy HH:mm', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Bermasalah'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final result = await showDialog<Map<String, int>>(
                context: context,
                builder: (ctx) => _MonthYearPickerDialog(
                  initialMonth: _selectedMonth,
                  initialYear: _selectedYear,
                ),
              );
              if (result != null && mounted) {
                setState(() {
                  _selectedMonth = result['month']!;
                  _selectedYear = result['year']!;
                });
              }
            },
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(
              _dateFmt.format(DateTime(_selectedYear, _selectedMonth)),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.print_rounded, size: 20, color: Colors.blue),
            tooltip: 'Cetak Laporan',
            color: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            onSelected: _printReport,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'gagal_kirim',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 20, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('Cetak Laporan Gagal Kirim'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'hilang',
                child: Row(
                  children: [
                    Icon(Icons.report_problem_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Cetak Laporan Barang Hilang'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Input manual — hanya admin cabang
          if (!_isSuperAdmin)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _resiManualC,
                      decoration: InputDecoration(
                        hintText: 'Input nomor resi manual...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          onPressed: _scanResi,
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    child: Tooltip(
                      message: 'Laporkan Kehilangan / Gagal Kirim',
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _laporkanManual,
                        icon: const Icon(Icons.report_problem, size: 18),
                        label: const Text('Laporkan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: _filter.isEmpty,
                  onSelected: (_) => setState(() => _filter = ''),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Gagal Kirim'),
                  selected: _filter == 'gagal_kirim',
                  onSelected: (_) => setState(
                    () =>
                        _filter = _filter == 'gagal_kirim' ? '' : 'gagal_kirim',
                  ),
                  selectedColor: Colors.orange.withValues(alpha: 0.2),
                  checkmarkColor: Colors.orange,
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Barang Hilang'),
                  selected: _filter == 'hilang',
                  onSelected: (_) => setState(
                    () => _filter = _filter == 'hilang' ? '' : 'hilang',
                  ),
                  selectedColor: Colors.red.withValues(alpha: 0.2),
                  checkmarkColor: Colors.red,
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Selesai'),
                  selected: _filter == 'kasus_selesai',
                  onSelected: (_) => setState(
                    () => _filter = _filter == 'kasus_selesai'
                        ? ''
                        : 'kasus_selesai',
                  ),
                  selectedColor: Colors.green.withValues(alpha: 0.2),
                  checkmarkColor: Colors.green,
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: FutureBuilder<List<Transaction>>(
              future: _loadBermasalah(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (_cachedBermasalah == null || list.isNotEmpty) {
                  _cachedBermasalah = list;
                }
                final filtered = _filter.isEmpty
                    ? list
                    : list
                          .where(
                            (tx) =>
                                tx.statusSaatIni == _filter ||
                                (_filter == 'gagal_kirim' &&
                                    tx.jenisMasalah == 'gagal_kirim'),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada resi bermasalah',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildItemCard(filtered[i], dateFmt),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Transaction tx, DateFormat dateFmt) {
    final pelapor = tx.dilaporkanOleh?['name'] as String? ?? '-';
    final cabangNama = tx.dilaporkanOleh?['cabang_name'] as String? ?? '-';
    final resolved = tx.statusSaatIni == 'kasus_selesai';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showDetail(tx),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tx.noResi,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(status: tx.statusSaatIni),
                      if (tx.jenisMasalah == 'gagal_kirim') ...[
                        const SizedBox(width: 4),
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
                              final user = ref.read(authProvider).user;
                              LabelPrinter.printBarcodeLabel(
                                data: tx.noResi,
                                pengirim: tx.pengirim,
                                penerima: tx.penerima,
                                paket: tx.paket,
                                createdAt: tx.createdAt,
                                asal:
                                    tx.createdBy['cabang_name']?.toString() ??
                                    '',
                                dicetakOleh: user?.lokasi?['name']?.toString(),
                              );
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
                              color: Colors.orange.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.print_rounded,
                              size: 18,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                      if (_isSuperAdmin &&
                          !resolved &&
                          tx.statusSaatIni == 'hilang') ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Tandai Selesai',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _tandaiSelesai(tx),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_isSuperAdmin && tx.jenisMasalah == 'hilang') ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Barang Ditemukan',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _batalkanHilang(tx),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.flip_to_back_rounded,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${tx.pengirimName} → ${tx.penerimaName}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dilaporkan oleh: $pelapor ($cabangNama)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (tx.dilaporkanPada != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt.format(tx.dilaporkanPada!.toLocal()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
              if (tx.catatanMasalah != null &&
                  tx.catatanMasalah!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: resolved
                        ? Colors.green.shade50
                        : tx.jenisMasalah == 'hilang'
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Catatan: ${tx.catatanMasalah}',
                    style: TextStyle(
                      fontSize: 12,
                      color: resolved
                          ? Colors.green.shade800
                          : tx.jenisMasalah == 'hilang'
                          ? Colors.red.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
              if (tx.jenisMasalah == 'gagal_kirim' &&
                  tx.tujuanSelanjutnya != null &&
                  tx.tujuanSelanjutnya!['nama'] != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.keyboard_return,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Retur ke: ${tx.tujuanSelanjutnya!['nama']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A3412),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (resolved && tx.diselesaikanOleh != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 13,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Diselesaikan oleh ${tx.diselesaikanOleh!['name']} pada ${tx.diselesaikanPada != null ? dateFmt.format(tx.diselesaikanPada!.toLocal()) : '-'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  final String title, name, phone, address;
  final IconData icon;
  final Color accentColor;

  const _DetailInfoCard({
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
}

class _CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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
  }
}

class _DetailInfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoCell({
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(12, (i) {
              final m = i + 1;
              final selected = _month == m;
              return GestureDetector(
                onTap: () => setState(() => _month = m),
                child: Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _months[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }),
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
