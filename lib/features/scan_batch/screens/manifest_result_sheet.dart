import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ManifestResultSheetData {
  final String id;
  final String noManifest;
  final int totalResi;
  final String tipeManifest;
  final int workUnit;
  final String driverName;
  final String tujuanNama;

  ManifestResultSheetData({
    required this.id,
    required this.noManifest,
    required this.totalResi,
    required this.tipeManifest,
    required this.workUnit,
    required this.driverName,
    required this.tujuanNama,
  });
}

Future<void> showManifestResultSheet(
  BuildContext context,
  ManifestResultSheetData data,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, scrollController) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Manifest Berhasil Dibuat!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),

              // Manifest number card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      data.noManifest,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(Icons.inventory_2_rounded, '${data.totalResi} Paket'),
                    const SizedBox(height: 6),
                    _infoRow(Icons.person_rounded, data.driverName),
                    const SizedBox(height: 6),
                    _infoRow(
                      data.tipeManifest == 'antar_cabang'
                          ? Icons.store_rounded
                          : Icons.location_on_rounded,
                      data.tujuanNama,
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.work_rounded,
                      'Work Unit: ${data.workUnit}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.pop();
                    context.push('/dashboard/manifest/${data.id}');
                  },
                  icon: const Icon(Icons.description_rounded, size: 18),
                  label: const Text(
                    'Lihat Detail Manifest',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Kembali ke Scan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _infoRow(IconData icon, String text) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 16, color: const Color(0xFF64748B)),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF475569),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
