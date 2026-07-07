import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/transaction.dart';
import 'resi_copy_button.dart';
import 'status_badge.dart';
import 'tracking_timeline.dart';

class TransactionDetailSheet extends StatelessWidget {
  final Transaction tx;
  final bool isDriver;
  final bool isAdminCabang;
  final String? currentCabangId;
  final VoidCallback? onCetakAsli;
  final VoidCallback? onCetakRetur;
  final VoidCallback? onLaporkanHilang;
  final VoidCallback? onSerahTerimaRetur;

  const TransactionDetailSheet({
    super.key,
    required this.tx,
    this.isDriver = false,
    this.isAdminCabang = false,
    this.currentCabangId,
    this.onCetakAsli,
    this.onCetakRetur,
    this.onLaporkanHilang,
    this.onSerahTerimaRetur,
  });

  static void show(
    BuildContext context, {
    required Transaction tx,
    bool isDriver = false,
    bool isAdminCabang = false,
    String? currentCabangId,
    VoidCallback? onCetakAsli,
    VoidCallback? onCetakRetur,
    VoidCallback? onLaporkanHilang,
    VoidCallback? onSerahTerimaRetur,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, scrollC) => TransactionDetailSheet(
          tx: tx,
          isDriver: isDriver,
          isAdminCabang: isAdminCabang,
          currentCabangId: currentCabangId,
          onCetakAsli: onCetakAsli,
          onCetakRetur: onCetakRetur,
          onLaporkanHilang: onLaporkanHilang,
          onSerahTerimaRetur: onSerahTerimaRetur,
        )._buildContent(scrollC),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollC) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final showDriver = _isDeliveredToRecipient(tx) && tx.namaDriver != null;

    return Container(
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
                              'Nomor Resi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tx.jenisPembayaran == 'cod' || tx.jenisPembayaran == 'tempo') ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: tx.jenisPembayaran == 'cod'
                                            ? const Color(0xFFF57F17)
                                            : const Color(0xFF2E7D32),
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                StatusBadge(
                                  status: tx.statusSaatIni,
                                  fontSize: 10,
                                ),
                              ],
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
                                      onCetakAsli?.call();
                                    } else {
                                      onCetakRetur?.call();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'asli',
                                      child: Row(
                                        children: [
                                          Icon(Icons.print_rounded, size: 18, color: Color(0xFF3B82F6)),
                                          SizedBox(width: 10),
                                          Text('Cetak Asli'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'retur',
                                      child: Row(
                                        children: [
                                          Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.orange.shade700),
                                          const SizedBox(width: 10),
                                          const Text('Cetak Resi Retur'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.print_rounded, size: 16, color: AppTheme.primary),
                                  ),
                                )
                              else
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onCetakAsli,
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
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _InfoCell(
                            icon: Icons.scale_rounded,
                            label: 'Berat',
                            value: tx.beratLabel,
                          ),
                        ),
                        Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                        Expanded(
                          child: _InfoCell(
                            icon: Icons.inventory_2_rounded,
                            label: 'Jumlah Koli',
                            value: '${tx.jumlahKoli} koli',
                          ),
                        ),
                        if (tx.biayaKirim > 0) ...[
                          Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _InfoCell(
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
                if (showDriver ||
                    (tx.namaPenerimaAkhir != null && tx.namaPenerimaAkhir!.isNotEmpty)) ...[
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
                        if (showDriver &&
                            tx.namaPenerimaAkhir != null &&
                            tx.namaPenerimaAkhir!.isNotEmpty)
                          const SizedBox(width: 8),
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
                Row(
                  children: [
                    const Text(
                      'RIWAYAT PENGIRIMAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 1,
                      ),
                    ),
                    if (isAdminCabang &&
                        tx.currentCabangId == currentCabangId &&
                        !['hilang', 'gagal_kirim', 'kasus_selesai', 'diterima'].contains(tx.statusSaatIni)) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Laporkan Kehilangan / Gagal Kirim',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onLaporkanHilang,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.report_problem_rounded, size: 16, color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                TrackingTimeline(logs: tx.trackingLogs),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return _buildContent(ScrollController());
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: accentColor.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.phone_rounded, size: 13, color: accentColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      phone,
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.w600, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor telepon disalin'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.content_copy_rounded, size: 13, color: accentColor),
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
