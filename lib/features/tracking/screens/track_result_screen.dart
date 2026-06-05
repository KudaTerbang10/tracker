import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/tracking_timeline.dart';
import '../../../shared/widgets/resi_copy_button.dart';
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
      appBar: AppBar(title: const Text('Tracking'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          String msg;
          IconData icon;
          if (e is DioException && e.type == DioExceptionType.connectionError) {
            msg = 'Tidak dapat terhubung ke server.\nPastikan backend berjalan.';
            icon = Icons.wifi_off;
          } else if (e is DioException && (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout)) {
            msg = 'Waktu koneksi habis.\nCoba lagi nanti.';
            icon = Icons.timer_off;
          } else {
            msg = 'Resi "$noResi" tidak ditemukan';
            icon = Icons.search_off;
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(msg, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => context.go('/'), child: const Text('Kembali')),
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
      if (log.status == 'keluar_konter' || log.status == 'keluar_gudang') {
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('No. Resi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      StatusBadge(status: tx.statusSaatIni),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          tx.noResi,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
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
                  child: _InfoCard(title: 'Penerima', name: tx.penerimaName, phone: tx.penerima['phone'] as String? ?? '', address: tx.penerimaAddress, icon: Icons.call_received),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoCard(title: 'Pengirim', name: tx.pengirimName, phone: tx.pengirim['phone'] as String? ?? '', address: tx.pengirim['address'] as String? ?? '', icon: Icons.send),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _InfoCell(icon: Icons.scale, label: 'Berat', value: tx.beratLabel)),
                    const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
                    Expanded(child: _InfoCell(icon: Icons.inventory_2, label: 'Koli', value: '${tx.jumlahKoli}')),
                    if (tx.biayaKirim > 0) ...[
                      const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
                      Expanded(child: _InfoCell(icon: Icons.payments, label: 'Biaya', value: fmt.format(tx.biayaKirim))),
                    ],
                  ],
                ),
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
                        title: 'Driver',
                        name: tx.namaDriver!,
                        phone: tx.kontakDriver ?? '',
                        address: '',
                        icon: Icons.person_pin,
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
                        icon: Icons.check_circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Riwayat Tracking', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TrackingTimeline(logs: tx.trackingLogs),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.statusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(StatusList.label(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.statusColor(status))),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title, name, phone, address;
  final IconData icon;
  const _InfoCard({required this.title, required this.name, required this.phone, required this.address, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primary.withValues(alpha: 0.12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                if (phone.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.black87),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(address, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
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
          Icon(icon, size: 22, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
