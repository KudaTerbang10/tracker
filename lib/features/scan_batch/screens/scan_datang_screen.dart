import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/utils/sound_player.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/scan_batch_provider.dart';

class ScanDatangScreen extends ConsumerStatefulWidget {
  const ScanDatangScreen({super.key});
  @override
  ConsumerState<ScanDatangScreen> createState() => _ScanDatangScreenState();
}

class _ScanDatangScreenState extends ConsumerState<ScanDatangScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(scanDatangProvider);
    final validCount = items.where((i) => i.isValid).length;
    final hasInvalid = items.any((i) => !i.isValid);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Scan Barang Datang'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: items.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Reset semua',
                  onPressed: () =>
                      ref.read(scanDatangProvider.notifier).clear(),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Status summary bar
          if (items.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$validCount barang valid',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (hasInvalid) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.error_rounded,
                        size: 16,
                        color: AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length - validCount} tidak valid',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Total: ${items.length}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Scan list / empty state
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return _buildScanCard(item);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (items.isNotEmpty) ...[
                GestureDetector(
                  onLongPress: _submitting
                      ? null
                      : () => ref.read(scanDatangProvider.notifier).clear(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text(
                      'SCAN RESI',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              if (validCount > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _confirm(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'KONFIRMASI',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 56,
                color: Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Siap Scan Barang',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol SCAN di bawah untuk mulai\n memindai barcode pada resi barang datang.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(ScanItem item) {
    final isValid = item.isValid;
    final statusColor = isValid ? const Color(0xFF10B981) : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                color: statusColor,
                size: 20,
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
                          item.noResi,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ResiCopyButton(resi: item.noResi),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.transaction.pengirimName} → ${item.transaction.penerimaName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _badge(
                        item.transaction.beratLabel,
                        const Color(0xFF0EA5E9),
                      ),
                      const SizedBox(width: 6),
                      _badge(
                        item.transaction.koliLabel,
                        const Color(0xFFF97316),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isValid
                        ? 'Siap diproses'
                        : (item.errorMessage ?? 'Tidak valid'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onLongPress: () =>
                  ref.read(scanDatangProvider.notifier).removeItem(item.noResi),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ),
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

  Future<void> _processResi(String code) async {
    final alreadyScanned = ref
        .read(scanDatangProvider)
        .any((i) => i.noResi == code);
    if (alreadyScanned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resi $code sudah discan sebelumnya')),
        );
      }
      return;
    }

    try {
      final res = await ApiService().get('${ApiConstants.track}/$code');
      final tx = Transaction.fromJson(res.data as Map<String, dynamic>);

      bool isValid = false;
      String? error;
      final role = ref.read(authProvider).user?.role ?? '';

      if (role == 'admin_cabang') {
        isValid = true;
        SoundPlayer.instance.playScan();
      } else {
        error = 'Role tidak memiliki akses scan datang';
      }

      ref
          .read(scanDatangProvider.notifier)
          .addItem(
            ScanItem(
              noResi: code,
              transaction: tx,
              isValid: isValid,
              errorMessage: error,
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resi $code tidak ditemukan')));
      }
    }
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerDialog.show(
      context,
      label: 'Scan barcode barang datang',
    );
    if (code == null || code.isEmpty) return;
    await _processResi(code);
  }

  Future<void> _confirm(BuildContext context) async {
    final items = ref.read(scanDatangProvider);
    final validItems = items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Penerimaan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${validItems.length} Paket',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'siap dikonfirmasi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Status paket akan diperbarui menjadi "Diterima Cabang".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(0, 44),
                ),
                child: const Text(
                  'KONFIRMASI',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('BATAL'),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final result = await repo.batchUpdateStatus(
        noResiList: validItems.map((i) => i.noResi).toList(),
        statusBaru: 'diterima_cabang',
      );

      if (mounted) {
        final berhasil = result['berhasil'] as int? ?? 0;
        final gagal = result['gagal'] as int? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $berhasil berhasil${gagal > 0 ? ', ❌ $gagal gagal' : ''}',
            ),
            backgroundColor: gagal > 0
                ? AppTheme.warning
                : const Color(0xFF10B981),
          ),
        );
        SoundPlayer.instance.playSuccess();
        ref.read(scanDatangProvider.notifier).clear();
      }
    } catch (e) {
      SoundPlayer.instance.playError();
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data?['message'] as String? ?? 'Gagal')
            : 'Gagal memperbarui status';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
