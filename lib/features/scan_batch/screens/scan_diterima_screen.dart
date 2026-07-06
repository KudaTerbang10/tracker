import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/utils/sound_player.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/providers/route_provider.dart';
import '../../driver/screens/driver_tab_screen.dart';

class ScanDiterimaScreen extends ConsumerStatefulWidget {
  const ScanDiterimaScreen({super.key});
  @override
  ConsumerState<ScanDiterimaScreen> createState() => _ScanDiterimaScreenState();
}

class _ScanDiterimaScreenState extends ConsumerState<ScanDiterimaScreen> {
  final _namaC = TextEditingController();
  final _catatanC = TextEditingController();
  bool _submitting = false;
  bool _capitalizing = false;
  Transaction? _tx;

  @override
  void dispose() {
    _namaC.dispose();
    _catatanC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Scan Barang Diterima'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _tx == null ? _buildEmptyState() : _buildDetailForm(),
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
          child: _tx == null
              ? Container(
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
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _tx = null;
                          _namaC.clear();
                          _catatanC.clear();
                        });
                      },
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
                          Icons.close_rounded,
                          color: AppTheme.error,
                          size: 22,
                        ),
                      ),
                    ),
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
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _confirm,
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
                                  'KONFIRMASI DITERIMA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                    ),
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
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onLongPress: _scan,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.handshake_rounded,
                    size: 56,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Konfirmasi Penerimaan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan barcode pada resi untuk mengkonfirmasi\nbahwa paket telah diterima oleh penerima.',
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

  Widget _buildDetailForm() {
    final tx = _tx!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resi info card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Detail Resi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      _badge(tx.beratLabel, const Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      _badge(tx.koliLabel, const Color(0xFFF97316)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tx.noResi,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 1,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        ResiCopyButton(resi: tx.noResi),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  _infoRow(
                    Icons.person_outline_rounded,
                    'Penerima',
                    tx.penerimaName,
                  ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.send_rounded, 'Pengirim', tx.pengirimName),
                  if (tx.jenisPembayaran == 'cod') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'COD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Nominal: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(tx.biayaKirim)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
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
          ),

          const SizedBox(height: 20),
          const Text(
            'INFORMASI PENERIMAAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),

          // Form fields
          TextField(
            controller: _namaC,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              if (_capitalizing) return;
              _capitalizing = true;
              final titled = _toTitleCase(v);
              if (titled != v) {
                _namaC.value = TextEditingValue(
                  text: titled,
                  selection: TextSelection.collapsed(offset: titled.length),
                );
              }
              _capitalizing = false;
            },
            decoration: const InputDecoration(
              labelText: 'Nama Penerima *',
              hintText: 'Masukkan nama yang menerima',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _catatanC,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Kondisi barang, keterangan tambahan, dll',
              prefixIcon: Icon(Icons.note_alt_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 80), // extra space for bottom bar
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerDialog.show(
      context,
      label: 'Scan barcode resi yang diterima',
    );
    if (code == null || code.isEmpty) return;

    try {
      final res = await ApiService().get('${ApiConstants.track}/$code');
      final tx = Transaction.fromJson(res.data as Map<String, dynamic>);

      // Validasi: driver yg ditugaskan atau admin cabang boleh scan diterima
      final user = ref.read(authProvider).user;
      final isAdminCabang = user?.isAdminCabang ?? false;
      if (!isAdminCabang && tx.driverUserId != user?.id) {
        SoundPlayer.instance.playError();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Anda tidak memiliki akses untuk transaksi ini',
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      SoundPlayer.instance.playScan();
      setState(() => _tx = tx);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resi $code tidak ditemukan')));
      }
    }
  }

  Future<void> _confirm() async {
    if (_namaC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama Penerima wajib diisi'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Cek pembayaran COD belum lunas (hanya admin cabang / walk-in)
    final user = ref.read(authProvider).user;
    final isAdminCabang = user?.isAdminCabang ?? false;
    if (isAdminCabang &&
        _tx!.jenisPembayaran == 'cod' &&
        _tx!.statusPembayaran == 'unpaid') {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 40,
          ),
          title: const Text('Pembayaran COD'),
          content: const Text(
            'Pembayaran COD transaksi ini belum dibayar, pastikan pembayaran sudah lunas!',
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Konfirmasi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    // Verifikasi lokasi sebelum konfirmasi
    if (_tx!.lokasiPenerima != null) {
      final proceed = await _checkLocationBeforeConfirm();
      if (!proceed) return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final result = await repo.batchUpdateStatus(
        noResiList: [_tx!.noResi],
        statusBaru: 'diterima',
        namaPenerima: _namaC.text.trim(),
        catatan: _catatanC.text.trim().isNotEmpty
            ? _catatanC.text.trim()
            : null,
      );

      if (mounted) {
        final berhasil = result['berhasil'] as int? ?? 0;
        final gagal = result['gagal'] as int? ?? 0;

        if (berhasil > 0) {
          SoundPlayer.instance.playSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$berhasil berhasil'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          // Refresh data driver dan rute
          ref.invalidate(routeProvider);
          ref.invalidate(kirimProvider);
          setState(() {
            _tx = null;
            _namaC.clear();
            _catatanC.clear();
          });
        } else {
          SoundPlayer.instance.playError();
          final results = result['results'] as List<dynamic>? ?? [];
          final msg = results.isNotEmpty
              ? (results[0] as Map)['error']?.toString() ?? 'Gagal'
              : 'Gagal memperbarui status';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
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

  Future<bool> _checkLocationBeforeConfirm() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Izin lokasi ditolak. Aktifkan GPS untuk konfirmasi.',
                ),
                backgroundColor: AppTheme.error,
              ),
            );
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin lokasi permanen ditolak. Buka Pengaturan untuk mengaktifkannya.',
              ),
              backgroundColor: AppTheme.error,
              duration: Duration(seconds: 4),
            ),
          );
          await Geolocator.openAppSettings();
        }
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final repo = ref.read(transactionRepositoryProvider);
      final verifyResult = await repo.verifyLocation(
        id: _tx!.id,
        lat: pos.latitude,
        lng: pos.longitude,
      );

      final isWithin = verifyResult['is_within'] as bool? ?? false;
      final distance = verifyResult['distance_meters'] as int? ?? 0;

      if (!isWithin && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.location_off_rounded,
              color: AppTheme.error,
              size: 40,
            ),
            title: const Text('Di Luar Jangkauan'),
            content: Text(
              'Anda berada ${distance}m dari lokasi penerima.\n\n'
              'Apakah tetap ingin konfirmasi penerimaan?',
              textAlign: TextAlign.center,
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                      ),
                      child: const Text('Konfirmasi'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        return proceed ?? false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 40,
            ),
            title: const Text('Verifikasi Lokasi Gagal'),
            content: Text(
              'Tidak dapat memverifikasi lokasi.\n${e.toString()}\n\n'
              'Tetap konfirmasi penerimaan?',
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Tetap Konfirmasi'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        return proceed ?? false;
      }
      return false;
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}
