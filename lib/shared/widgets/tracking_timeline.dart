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
    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('Belum ada riwayat tracking', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      );
    }

    final sorted = [...logs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final dateFmt = DateFormat('dd MMM yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm', 'id_ID');

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 8),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final log = sorted[i];
            final isFirst = i == 0;
            final isLast = i == sorted.length - 1;
            final color = isFirst ? AppTheme.statusColor(log.status) : const Color(0xFF94A3B8); // Slate-400
            final driverName = log.driverDitugaskan?['nama'] as String?;
            final subtitleParts = _buildSubtitle(log, driverName);

            String title;
            if (isLast && sorted.length > 1) {
              title = 'Paket diterima ekspedisi';
            } else if (log.status == 'diterima_cabang') {
              final loc = log.lokasiName;
              title = loc.isNotEmpty ? 'Diterima di $loc' : 'Diterima cabang';
            } else {
              title = StatusList.label(log.status);
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isFirst ? 0.15 : 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: isFirst ? 0.5 : 0.2),
                            width: isFirst ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          _statusIcon(log.status),
                          color: color,
                          size: 14,
                        ),
                      ),
                      Expanded(
                        child: isLast
                            ? const SizedBox.shrink()
                            : Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: const Color(0xFFE2E8F0),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 14,
                                    color: isFirst ? color : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${dateFmt.format(toJakarta(log.timestamp))}\n${timeFmt.format(toJakarta(log.timestamp))}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleParts.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              height: 1.3,
                            ),
                          ),
                          if (subtitleParts.$2 != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.directions_car_filled_rounded, size: 14, color: AppTheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    subtitleParts.$2!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  (String, String?) _buildSubtitle(TrackingLog log, String? driverName) {
    String main = '';
    String? driverLine;
    final loc = log.lokasiName;

    switch (log.status) {
      case 'diterima_cabang':
        main = 'Paket diterima di ${loc.isNotEmpty ? loc : 'cabang'}';
        break;
      case 'keluar_cabang':
        final tujuan = log.tujuan?['nama'] as String? ?? '';
        main = 'Paket keluar dari${loc.isNotEmpty ? ' $loc' : ' cabang'} menuju${tujuan.isNotEmpty ? ' $tujuan' : ' tujuan'}';
        if (driverName != null && driverName.isNotEmpty) driverLine = 'Kurir: $driverName';
        break;
      case 'proses_kirim':
        final tujuan = log.tujuan?['nama'] as String? ?? '';
        main = tujuan.isNotEmpty
            ? 'Paket dalam perjalanan menuju $tujuan'
            : 'Paket dalam perjalanan';
        if (driverName != null && driverName.isNotEmpty) driverLine = 'Kurir: $driverName';
        break;
      case 'diterima':
        if (log.deskripsi.isNotEmpty) {
          main = log.deskripsi;
        } else {
          final nama = log.namaPenerima ?? '';
          main = nama.isNotEmpty ? 'Diterima oleh $nama' : 'Paket telah diterima';
        }
        break;
      default:
        if (log.deskripsi.isNotEmpty) main = log.deskripsi;
    }

    return (main, driverLine);
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'diterima_cabang': return Icons.storefront_rounded;
      case 'keluar_cabang': return Icons.local_shipping_rounded;
      case 'proses_kirim': return Icons.near_me_rounded;
      case 'diterima': return Icons.task_alt_rounded;
      default: return Icons.radio_button_checked_rounded;
    }
  }
}
