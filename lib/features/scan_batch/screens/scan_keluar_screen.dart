import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/datasources/local/hive_cache.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/utils/sound_player.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/scan_batch_provider.dart';
import 'manifest_result_sheet.dart';
import '../../manifest/providers/manifest_provider.dart' as manifest_provider;

class ScanKeluarScreen extends ConsumerStatefulWidget {
  const ScanKeluarScreen({super.key});
  @override
  ConsumerState<ScanKeluarScreen> createState() => _ScanKeluarScreenState();
}

class _ScanKeluarScreenState extends ConsumerState<ScanKeluarScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanKeluarProvider);
    final notifier = ref.read(scanKeluarProvider.notifier);
    final validCount = state.validCount;
    final role = ref.read(authProvider).user?.role ?? '';
    final isAdminCabang = role == 'admin_cabang';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Scan Barang Keluar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: state.scannedItems.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Reset semua',
                  onPressed: () {},
                  onLongPress: () => notifier.clear(),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Driver & Tujuan card
          if (isAdminCabang && state.scannedItems.any((i) => i.isValid)) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_pin_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Data Driver & Tujuan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DriverAutocompleteField(
                    onSelected: (d) => notifier.setDriver(
                      d['user_id'].toString(),
                      d['name'].toString(),
                      d['phone'].toString(),
                    ),
                    onManualChanged: (name) {
                      if (name.trim().isNotEmpty) {
                        notifier.setDriverManual(name.trim(), '');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Ke Cabang Lain'),
                        selected: state.tujuanType == TujuanType.cabang,
                        onSelected: (v) =>
                            notifier.setTujuanType(TujuanType.cabang),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                        checkmarkColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: state.tujuanType == TujuanType.cabang
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: state.tujuanType == TujuanType.cabang
                              ? AppTheme.primary
                              : const Color(0xFF64748B),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: state.tujuanType == TujuanType.cabang
                                ? AppTheme.primary
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      if (isAdminCabang)
                        FilterChip(
                          label: const Text('Ke Penerima'),
                          selected: state.tujuanType == TujuanType.penerima,
                          onSelected: (v) =>
                              notifier.setTujuanType(TujuanType.penerima),
                          selectedColor: AppTheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          checkmarkColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: state.tujuanType == TujuanType.penerima
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: state.tujuanType == TujuanType.penerima
                                ? AppTheme.primary
                                : const Color(0xFF64748B),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: state.tujuanType == TujuanType.penerima
                                  ? AppTheme.primary
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (state.tujuanType == TujuanType.cabang) ...[
                    const SizedBox(height: 12),
                    _CabangAutocompleteField(
                      excludeCabangId: ref.read(authProvider).user?.cabangId,
                      onSelected: (c) => notifier.setCabangTujuan(
                        c['cabang_id'].toString(),
                        c['name'].toString(),
                      ),
                      onManualChanged: (name) {
                        if (name.trim().isNotEmpty) {
                          notifier.setCabangTujuanManual(name.trim());
                        }
                      },
                    ),
                  ],
                  if (state.tujuanType == TujuanType.penerima) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.info_rounded,
                            color: Colors.green,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Paket akan dikirim langsung ke alamat penerima',
                              style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Scan list / empty state
          Expanded(
            child: state.scannedItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: state.scannedItems.length,
                    itemBuilder: (_, i) {
                      final item = state.scannedItems[i];
                      return _buildScanCard(item, notifier);
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
                      'SCAN',
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
                      onPressed: _submitting
                          ? null
                          : () => _confirm(context, ref),
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Konfirmasi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$validCount',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
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

  Future<void> _processResi(String code) async {
    final alreadyScanned = ref
        .read(scanKeluarProvider)
        .scannedItems
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
        error = 'Role tidak memiliki akses scan keluar';
      }

      ref
          .read(scanKeluarProvider.notifier)
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
      label: 'Scan barcode barang keluar',
    );
    if (code == null || code.isEmpty) return;
    await _processResi(code);
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final state = ref.read(scanKeluarProvider);
    final validItems = state.scannedItems.where((i) => i.isValid).toList();

    if (validItems.isEmpty) return;

    final hasDriver =
        (state.driverUserId != null && state.driverUserId!.isNotEmpty) ||
        (state.driverName != null && state.driverName!.isNotEmpty);
    if (!hasDriver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama Driver wajib diisi'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (state.tujuanType == TujuanType.cabang) {
      final hasCabang =
          (state.cabangTujuanId != null && state.cabangTujuanId!.isNotEmpty) ||
          (state.cabangTujuanNama != null &&
              state.cabangTujuanNama!.isNotEmpty);
      if (!hasCabang) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cabang tujuan wajib diisi'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Kiriman',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: AppTheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
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
                          Text(
                            'dikirim dengan ${state.driverName ?? "-"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Status paket akan diperbarui menjadi "Keluar Cabang".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
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

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final statusBaru = 'keluar_cabang';

      final result = await repo.batchUpdateStatus(
        noResiList: validItems.map((i) => i.noResi).toList(),
        statusBaru: statusBaru,
        driverUserId: state.driverUserId,
        tipeTujuan: state.tujuanType == TujuanType.cabang
            ? 'cabang'
            : 'penerima',
        cabangTujuanId: state.tujuanType == TujuanType.cabang
            ? state.cabangTujuanId
            : null,
        namaDriverManual: state.driverUserId == null ? state.driverName : null,
        cabangNamaManual:
            (state.tujuanType == TujuanType.cabang &&
                state.cabangTujuanId == null)
            ? state.cabangTujuanNama
            : null,
      );

      if (mounted) {
        final berhasil = result['berhasil'] as int? ?? 0;
        final gagal = result['gagal'] as int? ?? 0;
        final results = result['results'] as List<dynamic>? ?? [];
        final manifestData = result['manifest'] as Map<String, dynamic>?;

        final errors = results.where((r) => r['status'] == 'error').map((r) => r['error'] as String? ?? '').where((e) => e.isNotEmpty).toList();

        if (manifestData != null) {
          ref.read(scanKeluarProvider.notifier).setManifestResult(manifestData);

          if (gagal > 0) {
            SoundPlayer.instance.playError();
          } else {
            SoundPlayer.instance.playSuccess();
          }

          setState(() => _submitting = false);
          await showManifestResultSheet(
            context,
            ManifestResultSheetData(
              id: manifestData['_id'] as String,
              noManifest: manifestData['no_manifest'] as String,
              totalResi: (manifestData['total_resi'] as num).toInt(),
              tipeManifest: manifestData['tipe_manifest'] as String,
              workUnit: (manifestData['work_unit'] as num).toInt(),
              driverName: (manifestData['driver']?['name'] as String?) ?? '-',
              tujuanNama: (manifestData['tujuan']?['nama'] as String?) ?? '-',
              jumlahKoli: (manifestData['jumlah_koli'] as num?)?.toInt() ?? 1,
              totalBerat:
                  (manifestData['total_berat'] as num?)?.toDouble() ?? 0,
            ),
          );

          // Refresh manifests di background
          final manifestProvider = await _getManifestProvider();
          if (manifestProvider != null) {
            ref.invalidate(manifestProvider);
          }
        } else if (gagal > 0) {
          SoundPlayer.instance.playError();
          setState(() => _submitting = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(errors.isNotEmpty ? errors.join(', ') : '$gagal gagal'),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          });
          // Jangan clear state agar user bisa lihat item yang gagal
          return;
        } else {
          SoundPlayer.instance.playSuccess();
          messenger.showSnackBar(
            SnackBar(
              content: Text('$berhasil berhasil'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        setState(() => _submitting = false);
        ref.read(scanKeluarProvider.notifier).clear();
      }
    } catch (e) {
      SoundPlayer.instance.playError();
      setState(() => _submitting = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e is DioException
                ? (e.response?.data?['message'] as String? ?? 'Gagal mengirim')
                : 'Gagal mengirim'),
            backgroundColor: AppTheme.error,
          ),
        );
      });
      return;
    }
    if (mounted) setState(() => _submitting = false);
  }

  /// Helper untuk invalidate manifest providers
  dynamic _getManifestProvider() => manifest_provider.driverManifestProvider;

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onLongPress: _scan,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(
                      255,
                      255,
                      121,
                      121,
                    ).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 56,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Siap Scan Barang Keluar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol SCAN di bawah untuk mulai\n memindai barcode pada resi barang keluar.',
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

  Widget _buildScanCard(ScanItem item, ScanKeluarNotifier notifier) {
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
                  const SizedBox(height: 4),
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
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
            GestureDetector(
              onLongPress: () => notifier.removeItem(item.noResi),
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
}

class _DriverAutocompleteField extends StatefulWidget {
  final void Function(Map<String, dynamic>) onSelected;
  final void Function(String) onManualChanged;
  const _DriverAutocompleteField({
    required this.onSelected,
    required this.onManualChanged,
  });

  @override
  State<_DriverAutocompleteField> createState() =>
      _DriverAutocompleteFieldState();
}

class _DriverAutocompleteFieldState extends State<_DriverAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (text) {
        if (text.text.isEmpty) return const Iterable.empty();
        return HiveCache.getDrivers(query: text.text);
      },
      displayStringForOption: (d) => '${d['name']} (${d['phone']})',
      onSelected: (d) {
        _controller.text = d['name'].toString();
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        widget.onSelected(d);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Nama Driver *',
            hintText: 'Ketik untuk cari...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            widget.onManualChanged(v);
          },
        );
      },
      optionsViewBuilder: (context, onSelectedCb, options) {
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 32,
                maxHeight: 240,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final d = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(d['name'].toString()),
                    subtitle: Text(d['phone'].toString()),
                    onTap: () {
                      _controller.text = d['name'].toString();
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                      onSelectedCb(d);
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CabangAutocompleteField extends StatefulWidget {
  final void Function(Map<String, dynamic>) onSelected;
  final void Function(String) onManualChanged;
  final String? excludeCabangId;
  const _CabangAutocompleteField({
    required this.onSelected,
    required this.onManualChanged,
    this.excludeCabangId,
  });

  @override
  State<_CabangAutocompleteField> createState() =>
      _CabangAutocompleteFieldState();
}

class _CabangAutocompleteFieldState extends State<_CabangAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  List<Map<String, dynamic>> _cabangs = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _loadCabangs();
  }

  Future<void> _loadCabangs() async {
    try {
      final res = await ApiService().get('/cabangs');
      final data = res.data['data'] as List<dynamic>;
      if (mounted) {
        setState(() {
          final all = data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cabangs = widget.excludeCabangId != null
              ? all
                    .where(
                      (c) =>
                          c['cabang_id']?.toString() != widget.excludeCabangId,
                    )
                    .toList()
              : all;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (text) {
        if (text.text.isEmpty) return const Iterable.empty();
        final q = text.text.toLowerCase();
        return _cabangs.where(
          (c) =>
              (c['name']?.toString() ?? '').toLowerCase().contains(q) ||
              (c['kode']?.toString() ?? '').toLowerCase().contains(q),
        );
      },
      displayStringForOption: (c) => '${c['kode']} - ${c['name']}',
      onSelected: (c) {
        _controller.text = c['name'].toString();
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        widget.onSelected(c);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Cabang Tujuan *',
            hintText: 'Ketik untuk cari...',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            widget.onManualChanged(v);
          },
        );
      },
      optionsViewBuilder: (context, onSelectedCb, options) {
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 32,
                maxHeight: 240,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final c = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text('${c['kode']} - ${c['name']}'),
                    subtitle: Text(c['address']?.toString() ?? ''),
                    onTap: () {
                      _controller.text = c['name'].toString();
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                      onSelectedCb(c);
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
