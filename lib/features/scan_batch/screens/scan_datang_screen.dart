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
    final role = ref.read(authProvider).user?.role ?? '';
    final isGudang = role == 'staff_gudang' || role == 'admin_cabang';
    final nextStatus = isGudang ? 'diterima_gudang' : 'diterima_konter';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barang Datang'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: items.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                  onPressed: () =>
                      ref.read(scanDatangProvider.notifier).clear(),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '$validCount barang valid',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (hasInvalid)
                    Text(
                      ' | ${items.length - validCount} tidak valid',
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  const Spacer(),
                  Text(
                    'Total: ${items.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tekan "SCAN" untuk mulai 📷',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan barcode pada resi barang yang datang',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            item.isValid ? Icons.check_circle : Icons.error,
                            color: item.isValid ? Colors.green : AppTheme.error,
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  item.noResi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              ResiCopyButton(resi: item.noResi),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.transaction.pengirimName} → ${item.transaction.penerimaName}',
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _badge(item.transaction.beratLabel, Colors.blue),
                                  const SizedBox(width: 6),
                                  _badge(item.transaction.koliLabel, Colors.orange),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.isValid
                                    ? 'Siap diproses'
                                    : item.errorMessage ?? 'Tidak valid',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item.isValid ? Colors.green : AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                          trailing: GestureDetector(
                            onLongPress: () => ref
                                .read(scanDatangProvider.notifier)
                                .removeItem(item.noResi),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.close, size: 16, color: Colors.red.shade700),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (items.isNotEmpty)
                GestureDetector(
                  onLongPress: _submitting
                      ? null
                      : () => ref.read(scanDatangProvider.notifier).clear(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, color: Colors.red.shade700, size: 20),
                  ),
                ),
              if (items.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                flex: items.isNotEmpty ? 1 : 1,
                child: ElevatedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('SCAN'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (validCount > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () => _confirm(context, nextStatus),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('KONFIRMASI'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processResi(String code) async {
    final alreadyScanned =
        ref.read(scanDatangProvider).any((i) => i.noResi == code);
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

      if (role == 'staff_gudang' || role == 'admin_konter' || role == 'admin_cabang') {
        isValid = true;
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

  Future<void> _confirm(BuildContext context, String nextStatus) async {
    final items = ref.read(scanDatangProvider);
    final validItems = items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text('Konfirmasi ${validItems.length} barang diterima?'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text('KONFIRMASI'),
              ),
              const SizedBox(height: 4),
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
        statusBaru: nextStatus,
      );

      if (mounted) {
        final berhasil = result['berhasil'] as int? ?? 0;
        final gagal = result['gagal'] as int? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $berhasil berhasil' + (gagal > 0 ? ', ❌ $gagal gagal' : ''),
            ),
            backgroundColor: gagal > 0 ? AppTheme.warning : Colors.green,
          ),
        );
        ref.read(scanDatangProvider.notifier).clear();
      }
    } catch (e) {
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
