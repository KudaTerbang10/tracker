import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../data/models/manifest.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../providers/manifest_provider.dart';
import '../utils/manifest_print.dart';

class ManifestDetailScreen extends ConsumerWidget {
  final String manifestId;
  const ManifestDetailScreen({super.key, required this.manifestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manifestDetailProvider(manifestId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Detail Manifest'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          async.whenOrNull(
                data: (m) => m != null
                    ? PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.print_rounded,
                          color: AppTheme.primary,
                        ),
                        tooltip: 'Cetak',
                        color: Colors.white,
                        surfaceTintColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        onSelected: (value) {
                          if (value == 'a4') {
                            printManifestA4(m);
                          } else if (value == '80mm') {
                            printManifest80mm(m);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'a4',
                            child: Row(
                              children: [
                                Icon(Icons.description_outlined, size: 18, color: Color(0xFF3B82F6)),
                                SizedBox(width: 10),
                                Text('Print A4'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: '80mm',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF3B82F6)),
                                SizedBox(width: 10),
                                Text('Print 80 mm'),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (manifest) {
          if (manifest == null) {
            return const Center(child: Text('Manifest tidak ditemukan'));
          }
          return _buildContent(context, manifest, ref);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Manifest manifest, WidgetRef ref) {
    final txs = manifest.transactions ?? <Transaction>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        _headerCard(context, manifest),
        const SizedBox(height: 12),

        // Info + Driver card — row on wide, stacked on mobile
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 768) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _infoCard(manifest)),
                    const SizedBox(width: 12),
                    Expanded(child: _peopleCard(manifest)),
                  ],
                ),
              );
            }
            return Column(
              children: [
                _infoCard(manifest),
                const SizedBox(height: 12),
                _peopleCard(manifest),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // Summary card
        _summaryCard(manifest),
        const SizedBox(height: 12),

        // Daftar resi header
        Row(
          children: [
            const Icon(
              Icons.list_alt_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              'DAFTAR RESI (${txs.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Each resi card
        ...txs.map((tx) => _resiCard(context, tx)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _headerCard(BuildContext context, Manifest m) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: m.isAntarCabang
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.description_rounded,
                size: 28,
                color: m.isAntarCabang ? AppTheme.primary : Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            m.noManifest,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: m.noManifest));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nomor manifest disalin'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _statusBadge(m.statusLabel, m.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(Manifest m) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Informasi Pengiriman',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRowItem(Icons.store_rounded, 'Asal', m.asalCabangName),
            const Divider(height: 20),
            _infoRowItem(
              m.isAntarCabang ? Icons.store_rounded : Icons.location_on_rounded,
              'Tujuan',
              m.tujuanNama,
            ),
            const Divider(height: 20),
            _infoRowItem(Icons.category_rounded, 'Tipe', m.tipeLabel),
            const Divider(height: 20),
            _infoRowItem(
              Icons.card_giftcard_rounded,
              'Total Koli',
              '${m.jumlahKoli} koli',
            ),
            const Divider(height: 20),
            _infoRowItem(
              Icons.monitor_weight_rounded,
              'Total Berat',
              '${m.totalBerat.toStringAsFixed(1)} kg',
            ),
          ],
        ),
      ),
    );
  }

  Widget _peopleCard(Manifest m) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Driver & Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRowItem(Icons.person_rounded, 'Driver', m.driverName),
            const Divider(height: 20),
            if (m.driverPhone.isNotEmpty) ...[
              _infoRowItem(Icons.phone_rounded, 'Kontak', m.driverPhone),
              const Divider(height: 20),
            ],
            _infoRowItem(
              Icons.person_add_rounded,
              'Dibuat oleh',
              m.createdBy['name'] as String? ?? '',
            ),
            const Divider(height: 20),
            _infoRowItem(
              Icons.business_rounded,
              'Cabang',
              m.createdBy['cabang_name'] as String? ?? '',
            ),
            const Divider(height: 20),
            _infoRowItem(
              Icons.access_time_rounded,
              'Dibuat pada',
              DateFormat(
                'dd MMM yyyy, HH:mm',
                'id_ID',
              ).format(toJakarta(m.createdAt)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(Manifest m) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _sumItem('${m.totalResi}', 'Total Resi'),
            Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
            _sumItem('${m.workUnit}', 'Work Unit'),
            Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
            _sumItem(
              m.progressSelesai != null
                  ? '${m.progressSelesai}/${m.totalResi}'
                  : '-',
              'Selesai',
            ),
          ],
        ),
      ),
    );
  }

  Widget _resiCard(BuildContext context, Transaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: () => _showTransactionDetail(context, tx),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isSelesai(tx.statusSaatIni)
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isSelesai(tx.statusSaatIni)
                          ? Icons.check_circle_rounded
                          : Icons.pending_rounded,
                      size: 18,
                      color: _isSelesai(tx.statusSaatIni)
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tx.noResi,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ResiCopyButton(resi: tx.noResi),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tx.pengirimName} → ${tx.penerimaName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _badge(tx.beratLabel, AppTheme.primary),
                            const SizedBox(width: 6),
                            _badge(tx.koliLabel, const Color(0xFFF97316)),
                            const SizedBox(width: 8),
                            Text(
                              tx.statusSaatIni == 'diterima'
                                  ? 'Diterima ✅'
                                  : tx.statusSaatIni == 'diterima_cabang'
                                  ? 'Di ${tx.diterimaDiCabang.isNotEmpty ? tx.diterimaDiCabang : 'Cabang'}'
                                  : 'Dalam Perjalanan',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _isSelesai(tx.statusSaatIni)
                                    ? Colors.green
                                    : Colors.orange,
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
        ),
      ),
    );
  }

  bool _isSelesai(String status) =>
      status == 'diterima' || status == 'diterima_cabang';

  void _showTransactionDetail(BuildContext context, Transaction tx) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
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
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollC,
                  padding: const EdgeInsets.all(16),
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
                                tx.statusSaatIni == 'diterima_cabang'
                                    ? _cabangBadge(tx.diterimaDiCabang)
                                    : StatusBadge(
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
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _detailInfoCard(
                              context,
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
                            child: _detailInfoCard(
                              context,
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
                              child: _detailInfoCell(
                                Icons.scale_rounded,
                                'Berat',
                                tx.beratLabel,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: const Color(0xFFE2E8F0),
                            ),
                            Expanded(
                              child: _detailInfoCell(
                                Icons.inventory_2_rounded,
                                'Jumlah Koli',
                                '${tx.jumlahKoli} koli',
                              ),
                            ),
                            if (tx.biayaKirim > 0) ...[
                              Container(
                                width: 1,
                                height: 40,
                                color: const Color(0xFFE2E8F0),
                              ),
                              Expanded(
                                child: _detailInfoCell(
                                  Icons.payments_rounded,
                                  'Biaya Kirim',
                                  fmt.format(tx.biayaKirim),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
                                child: _detailInfoCard(
                                  context,
                                  'Driver Kurir',
                                  tx.namaDriver!,
                                  tx.kontakDriver ?? '',
                                  '',
                                  Icons.directions_car_filled_rounded,
                                  Colors.amber.shade700,
                                ),
                              ),
                            if (showDriver &&
                                tx.namaPenerimaAkhir != null &&
                                tx.namaPenerimaAkhir!.isNotEmpty)
                              const SizedBox(width: 8),
                            if (tx.namaPenerimaAkhir != null &&
                                tx.namaPenerimaAkhir!.isNotEmpty)
                              Expanded(
                                child: _detailInfoCard(
                                  context,
                                  'Diterima oleh',
                                  tx.namaPenerimaAkhir!,
                                  '',
                                  '',
                                  Icons.check_circle_rounded,
                                  Colors.green.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_canReportProblem(context, tx))
                      _buildLaporkanHilangButton(context, tx),
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

  bool _canReportProblem(BuildContext context, Transaction tx) {
    if (['hilang', 'gagal_kirim', 'kasus_selesai', 'diterima'].contains(tx.statusSaatIni)) return false;
    final user = ProviderScope.containerOf(context).read(authProvider).user;
    if (user == null || !user.isAdminCabang) return false;
    return tx.currentCabangId == user.cabangId;
  }

  Widget _buildLaporkanHilangButton(BuildContext context, Transaction tx) {
    return ElevatedButton.icon(
      onPressed: () async {
        final jenis = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Laporkan Masalah'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Resi: ${tx.noResi}'),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.red),
                  title: const Text('Barang Hilang'),
                  subtitle: const Text('Paket tidak ditemukan saat verifikasi'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () => Navigator.of(ctx).pop('hilang'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.orange),
                  title: const Text('Gagal Kirim'),
                  subtitle: const Text('Paket tidak dapat dikirim, retur ke pengirim'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () => Navigator.of(ctx).pop('gagal_kirim'),
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal'))],
          ),
        );
        if (jenis == null || !context.mounted) return;

        final catatanC = TextEditingController();
        final catatan = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${jenis == 'hilang' ? 'Barang Hilang' : 'Gagal Kirim'} — Catatan'),
            content: TextField(
              controller: catatanC,
              decoration: const InputDecoration(hintText: 'Deskripsi / kronologi...', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () { catatanC.dispose(); Navigator.of(ctx).pop(); }, child: const Text('Batal')),
              TextButton(
                onPressed: () { final v = catatanC.text.trim(); catatanC.dispose(); Navigator.of(ctx).pop(v.isEmpty ? null : v); },
                child: const Text('Laporkan'),
              ),
            ],
          ),
        );
        if (catatan == null || !context.mounted) return;

        try {
          await ProviderScope.containerOf(context).read(transactionRepositoryProvider).laporkanMasalah(id: tx.id, jenis: jenis, catatan: catatan);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Resi ${tx.noResi} dilaporkan ${jenis == 'hilang' ? 'Hilang' : 'Gagal Kirim'}'),
              backgroundColor: jenis == 'hilang' ? Colors.red : Colors.orange,
            ));
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
          }
        }
      },
      icon: const Icon(Icons.report_problem_rounded, size: 18),
      label: const Text('Laporkan Barang Hilang'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _detailInfoCard(
    BuildContext ctx,
    String title,
    String name,
    String phone,
    String address,
    IconData icon,
    Color accent,
  ) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
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
                  Icon(Icons.phone_iphone_rounded, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      phone,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Nomor telepon disalin'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.content_copy_rounded, size: 13, color: accent),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailInfoCell(IconData icon, String label, String value) {
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

  Widget _infoRowItem(
    IconData icon,
    String label,
    String value, {
    Widget? badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (badge != null) badge,
      ],
    );
  }

  Widget _labelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _cabangBadge(String cabangNama) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Diterima di ${cabangNama.isNotEmpty ? cabangNama : 'Cabang'}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _statusBadge(String label, String status) {
    Color color;
    switch (status) {
      case 'dibuat':
        color = const Color(0xFFF59E0B);
        break;
      case 'dalam_perjalanan':
        color = AppTheme.primary;
        break;
      case 'selesai':
        color = Colors.green;
        break;
      default:
        color = const Color(0xFF94A3B8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

}
