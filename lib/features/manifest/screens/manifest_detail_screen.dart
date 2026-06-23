import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../data/models/manifest.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../providers/manifest_provider.dart';

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
                          color: Color(0xFF3B82F6),
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
                            _printManifestA4(context, m);
                          } else if (value == '80mm') {
                            _printManifest80mm(context, m);
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
        _headerCard(manifest),
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

  Widget _headerCard(Manifest m) {
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
                  Text(
                    m.noManifest,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                      color: Color(0xFF0F172A),
                    ),
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
                      ScaffoldMessenger.of(ctx).showSnackBar(
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

  Future<void> _printManifestA4(BuildContext context, Manifest m) async {
    final txs = m.transactions ?? <Transaction>[];
    final fmtDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
    final now = fmtDate.format(toJakarta(DateTime.now()));

    final logoData = await rootBundle.load('assets/pics/hiralogo.webp');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logoImage, height: 50),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HIRA EXPRESS',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'MANIFEST PENGIRIMAN',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      m.noManifest,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        fontFallback: [pw.Font.courier()],
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Dicetak: $now',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: m.noManifest,
                width: 240,
                height: 50,
              ),
            ],
          ),
          pw.Divider(height: 24, thickness: 1),

          // Info section
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfLabel('Asal', m.asalCabangName),
                    pw.SizedBox(height: 4),
                    _pdfLabel('Tujuan', m.tujuanNama),
                    pw.SizedBox(height: 4),
                    _pdfLabel('Tipe', m.tipeLabel),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfLabel('Driver', m.driverName),
                    pw.SizedBox(height: 4),
                    _pdfLabel('Kontak', m.driverPhone),
                    pw.SizedBox(height: 4),
                    _pdfLabel('Work Unit', '${m.workUnit}'),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: m.noManifest,
                width: 55,
                height: 55,
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FixedColumnWidth(130),
              2: const pw.FixedColumnWidth(105),
              3: const pw.FixedColumnWidth(105),
              4: const pw.FixedColumnWidth(45),
              5: const pw.FixedColumnWidth(40),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _pdfCell('No', header: true),
                  _pdfCell('No. Resi', header: true),
                  _pdfCell('Pengirim', header: true),
                  _pdfCell('Penerima', header: true),
                  _pdfCell('Berat', header: true),
                  _pdfCell('Koli', header: true),
                ],
              ),
              // Data rows
              ...txs.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final tx = entry.value;
                return pw.TableRow(
                  children: [
                    _pdfCell('$i'),
                    _pdfCell(tx.noResi, font: pw.Font.courier()),
                    _pdfCell(tx.pengirimName),
                    _pdfCell(tx.penerimaName),
                    _pdfCell(tx.beratLabel),
                    _pdfCell(tx.koliLabel),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),

          // Summary
          pw.Row(
            children: [
              _pdfLabel('Total Resi: ${txs.length}'),
              pw.SizedBox(width: 24),
              _pdfLabel(
                'Total Berat: ${txs.fold(0.0, (sum, tx) => sum + (tx.paket['berat_kg'] as num? ?? 0).toDouble()).toStringAsFixed(1)} kg',
              ),
              pw.SizedBox(width: 24),
              _pdfLabel(
                'Total Koli: ${txs.fold(0, (sum, tx) => sum + (tx.paket['jumlah_koli'] as num? ?? 0).toInt())}',
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // Signature lines
          if (m.isAntarCabang) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      'Admin ${m.asalCabangName}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 32),
                    pw.Text(
                      '(_______________)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Driver', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 32),
                    pw.Text(
                      '(_______________)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'Admin ${m.tujuanNama}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 32),
                    pw.Text(
                      '(_______________)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      'Admin ${m.asalCabangName}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 32),
                    pw.Text(
                      '(_______________)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(width: 80),
                pw.Column(
                  children: [
                    pw.Text('Driver', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 32),
                    pw.Text(
                      '(_______________)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  Future<void> _printManifest80mm(BuildContext context, Manifest m) async {
    final txs = m.transactions ?? <Transaction>[];
    final fmtDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
    final tglBuat = fmtDate.format(toJakarta(m.createdAt));
    final tglCetak = fmtDate.format(toJakarta(DateTime.now()));

    final logoData = await rootBundle.load('assets/pics/hiralogo.webp');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final totalBerat = txs.fold(
      0.0,
      (sum, tx) => sum + (tx.paket['berat_kg'] as num? ?? 0).toDouble(),
    );
    final totalKoli = txs.fold(
      0,
      (sum, tx) => sum + (tx.paket['jumlah_koli'] as num? ?? 0).toInt(),
    );

    const pageFmt = PdfPageFormat(
      78 * PdfPageFormat.mm,
      100 * PdfPageFormat.mm,
    );
    const margin = pw.EdgeInsets.all(6);

    // Header widget
    pw.Widget header() {
      const s = pw.TextStyle(fontSize: 6);
      final lbl = pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logoImage, height: 16),
              pw.Expanded(child: pw.SizedBox()),
              pw.Text(
                'MANIFEST PENGIRIMAN',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: m.noManifest,
            width: 150,
            height: 40,
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Dibuat', style: lbl),
                  pw.Text('Cetak', style: lbl),
                  pw.Text('Asal', style: lbl),
                  pw.Text('Tujuan', style: lbl),
                  pw.Text('Driver', style: lbl),
                  if (m.driverPhone.isNotEmpty) pw.Text('Kontak', style: lbl),
                ],
              ),
              pw.SizedBox(width: 4),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(tglBuat, style: s),
                  pw.Text(tglCetak, style: s),
                  pw.Text(m.asalCabangName, style: s),
                  pw.Text(m.tujuanNama, style: s),
                  pw.Text(m.driverName, style: s),
                  if (m.driverPhone.isNotEmpty)
                    pw.Text(m.driverPhone, style: s),
                ],
              ),
              pw.Expanded(child: pw.SizedBox()),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: m.noManifest,
                width: 38,
                height: 38,
              ),
            ],
          ),
          pw.Divider(thickness: 0.5),
          pw.Center(
            child: pw.Text(
              'DAFTAR RESI',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 2),
        ],
      );
    }

    // Resi card widget
    pw.Widget card(int i, Transaction tx) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 2),
        padding: const pw.EdgeInsets.all(2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Text(
                  '$i.',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 3),
                pw.Expanded(
                  child: pw.Text(
                    tx.noResi,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      fontFallback: [pw.Font.courier()],
                    ),
                  ),
                ),
              ],
            ),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Pengirim: ${tx.pengirimName}',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ),
                pw.Text(
                  tx.beratLabel,
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 3),
                pw.Text(
                  tx.koliLabel,
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Text(
              'Penerima: ${tx.penerimaName}',
              style: const pw.TextStyle(fontSize: 6),
            ),
            if (tx.penerimaAddress.isNotEmpty)
              pw.Text(
                tx.penerimaAddress,
                style: const pw.TextStyle(fontSize: 6),
              ),
          ],
        ),
      );
    }

    // Summary widget
    pw.Widget summary() {
      return pw.Column(
        children: [
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Total Resi: ${txs.length}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                'Berat: ${totalBerat.toStringAsFixed(1)} kg',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                'Koli: $totalKoli',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
      );
    }

    // Signature widget — 3 baris vertikal rata tengah
    pw.Widget sig() {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Center(child: _ttdRow('Admin ${m.asalCabangName}')),
          pw.SizedBox(height: 14),
          pw.Center(child: _ttdRow('Driver')),
          if (m.isAntarCabang) ...[
            pw.SizedBox(height: 14),
            pw.Center(child: _ttdRow('Admin ${m.tujuanNama}')),
          ],
        ],
      );
    }

    // --- Split content into pages ---
    final cards = txs
        .asMap()
        .entries
        .map((e) => card(e.key + 1, e.value))
        .toList();
    final allPages = <pw.Widget>[];

    if (cards.isEmpty) {
      allPages.add(pw.Column(children: [header(), summary(), sig()]));
    } else {
      int idx = 0;
      // First page: header + ~3 cards
      final first = <pw.Widget>[header()];
      for (int i = 0; i < 4 && idx < cards.length; i++, idx++) {
        first.add(cards[idx]);
      }
      allPages.add(pw.Column(children: first));

      // Middle pages: ~5 cards each
      while (idx + 5 <= cards.length) {
        final middle = <pw.Widget>[];
        for (int i = 0; i < 5; i++, idx++) {
          middle.add(cards[idx]);
        }
        allPages.add(pw.Column(children: middle));
      }

      // Last page: remaining cards + summary + signature
      final last = <pw.Widget>[];
      while (idx < cards.length) {
        last.add(cards[idx++]);
      }
      last.addAll([summary(), sig()]);
      allPages.add(pw.Column(children: last));
    }

    // Add pages in REVERSE order: last page prints first, page 1 on top
    final pdf = pw.Document();
    for (int i = allPages.length - 1; i >= 0; i--) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFmt,
          margin: margin,
          build: (_) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: allPages[i],
          ),
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  pw.Widget _pdfLabel(String label, [String? value]) {
    return pw.Text(
      value != null ? '$label: $value' : label,
      style: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _pdfCell(String text, {bool header = false, pw.Font? font}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _ttdRow(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 28),
        pw.Text('(_______________)', style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }
}
