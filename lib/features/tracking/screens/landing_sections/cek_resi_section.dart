import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../../shared/widgets/tracking_timeline.dart';
import '../../../../shared/widgets/resi_copy_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../data/models/transaction.dart';
import '../../screens/track_result_screen.dart';

class CekResiSection extends ConsumerStatefulWidget {
  final GlobalKey sectionKey;
  const CekResiSection({super.key, required this.sectionKey});

  @override
  ConsumerState<CekResiSection> createState() => _CekResiSectionState();
}

class _CekResiSectionState extends ConsumerState<CekResiSection> {
  final _resiC = TextEditingController();

  @override
  void dispose() {
    _resiC.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerDialog.show(context);
    if (code != null && code.isNotEmpty) {
      _resiC.text = code.toUpperCase();
      _track();
    }
  }

  void _track() {
    final resi = _resiC.text.trim().toUpperCase();
    if (resi.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrackingBottomSheet(noResi: resi),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: widget.sectionKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const Text(
                  'Cek Resi Pengiriman',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lacak posisi terbaru kiriman Anda secara real-time',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.route_rounded,
                            color: AppTheme.primary,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _resiC,
                          decoration: InputDecoration(
                            labelText: 'Masukkan No. Resi',
                            hintText: 'Contoh: CKG-20270710-0002',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.only(right: 6),
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
                                onPressed: _scanBarcode,
                              ),
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onFieldSubmitted: (_) => _track(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _track,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.track_changes_rounded, size: 22),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Lacak Sekarang',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingBottomSheet extends ConsumerWidget {
  final String noResi;
  const _TrackingBottomSheet({required this.noResi});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trackProvider(noResi));
    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, scrollC) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Resi "$noResi" tidak ditemukan',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (tx) => _buildContent(context, tx, scrollC),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Transaction tx,
    ScrollController scrollC,
  ) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Column(
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
                              StatusBadge(status: tx.statusSaatIni, fontSize: 10),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx.noResi,
                              style: const TextStyle(
                                fontSize: 20,
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
              if (tx.statusSaatIni != 'hilang' && tx.statusSaatIni != 'kasus_selesai') TrackingMap(tx: tx),
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
                        child: _InfoCell(
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
                        child: _InfoCell(
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
              if (tx.namaDriver != null && tx.tujuanSelanjutnya?['tipe'] != 'cabang') ...[
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      if (tx.namaPenerimaAkhir != null &&
                          tx.namaPenerimaAkhir!.isNotEmpty) ...[
                        const SizedBox(width: 8),
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
    );
  }
}

// Copy of _InfoCard and _InfoCell from track_result_screen
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
            width: double.infinity,
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
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        height: 1.3,
                      ),
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
                  Icon(Icons.phone_iphone_rounded, size: 11, color: accentColor),
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
