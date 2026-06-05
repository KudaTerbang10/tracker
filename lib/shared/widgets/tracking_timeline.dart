import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/datetime_utils.dart';
import '../../data/models/tracking_log.dart';

class TrackingTimeline extends StatelessWidget {
  final List<TrackingLog> logs;
  const TrackingTimeline({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Belum ada riwayat tracking')));

    final sorted = [...logs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final dateFmt = DateFormat('dd/MM/yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm', 'id_ID');

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) {
          final log = sorted[i];
          final isFirst = i == 0;
          final color = isFirst ? AppTheme.statusColor(log.status) : Colors.grey.shade400;
          final driverName = log.driverDitugaskan?['nama'] as String?;
          final subtitleParts = _buildSubtitle(log, driverName);
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_statusIcon(log.status), color: color, size: 20),
            ),
            title: Text(StatusList.label(log.status), style: TextStyle(fontWeight: isFirst ? FontWeight.bold : FontWeight.normal, color: isFirst ? color : null)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitleParts.$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                  ),
                  if (subtitleParts.$2 != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitleParts.$2!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            trailing: Text('${dateFmt.format(toJakarta(log.timestamp))} ${timeFmt.format(toJakarta(log.timestamp))}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          );
        },
      ),
    );
  }

  (String, String?) _buildSubtitle(TrackingLog log, String? driverName) {
    String main = '';
    String? driverLine;
    final loc = log.lokasiName;

    switch (log.status) {
      case 'diterima_konter':
        main = 'Paket diterima di konter${loc.isNotEmpty ? ' $loc' : ''}';
        break;
      case 'diterima_gudang':
        main = 'Paket diterima di gudang${loc.isNotEmpty ? ' $loc' : ''}';
        break;
      case 'keluar_konter':
        final tujuan = log.tujuan?['nama'] as String? ?? '';
        main = 'Paket meninggalkan${loc.isNotEmpty ? ' $loc' : ' konter'} menuju${tujuan.isNotEmpty ? ' $tujuan' : ' gudang'}';
        if (driverName != null && driverName.isNotEmpty) driverLine = 'Kurir: $driverName';
        break;
      case 'keluar_gudang':
        final tujuan = log.tujuan?['nama'] as String? ?? 'penerima';
        main = 'Paket keluar dari${loc.isNotEmpty ? ' $loc' : ' gudang'} menuju $tujuan';
        if (driverName != null && driverName.isNotEmpty) driverLine = 'Kurir: $driverName';
        break;
      case 'proses_kirim':
        main = driverName != null && driverName.isNotEmpty
            ? 'Dalam perjalanan oleh $driverName'
            : 'Paket dalam perjalanan';
        break;
      case 'diterima':
        final nama = log.namaPenerima ?? '';
        main = nama.isNotEmpty ? 'Diterima oleh $nama' : 'Paket telah diterima';
        break;
      default:
        if (log.deskripsi.isNotEmpty) main = log.deskripsi;
    }

    return (main, driverLine);
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'diterima_konter': return Icons.store;
      case 'keluar_konter': return Icons.directions_walk;
      case 'diterima_gudang': return Icons.warehouse;
      case 'keluar_gudang': return Icons.local_shipping;
      case 'proses_kirim': return Icons.route;
      case 'diterima': return Icons.check_circle;
      default: return Icons.circle;
    }
  }
}
