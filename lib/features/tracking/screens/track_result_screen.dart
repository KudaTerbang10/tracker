import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/track_repository.dart';
import 'package:intl/intl.dart';

final _trackProvider = FutureProvider.autoDispose.family<Transaction, String>((ref, noResi) {
  return ref.read(trackRepositoryProvider).trackByResi(noResi);
});

class TrackResultScreen extends ConsumerWidget {
  final String noResi;
  const TrackResultScreen({super.key, required this.noResi});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_trackProvider(noResi));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          String msg;
          IconData icon;
          if (e is DioException && e.type == DioExceptionType.connectionError) {
            msg = 'Tidak dapat terhubung ke server.\nPastikan backend berjalan.';
            icon = Icons.wifi_off_rounded;
          } else if (e is DioException && (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout)) {
            msg = 'Waktu koneksi habis.\nCoba lagi nanti.';
            icon = Icons.timer_off_rounded;
          } else {
            msg = 'Resi "$noResi" tidak ditemukan';
            icon = Icons.search_off_rounded;
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: const Color(0xFF94A3B8)),
                  const SizedBox(height: 16),
                  Text(msg, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569)), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Kembali'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        data: (tx) => _TrackDetail(tx: tx),
      ),
    );
  }
}

class _TrackDetail extends StatelessWidget {
  final Transaction tx;
  const _TrackDetail({required this.tx});

  bool get _isDeliveredToRecipient {
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
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final showDriver = _isDeliveredToRecipient && tx.namaDriver != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      StatusBadge(status: tx.statusSaatIni, fontSize: 10),
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
                        accentColor: const Color(0xFF10B981),
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
    );
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
