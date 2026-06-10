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

class ScanDiterimaScreen extends ConsumerStatefulWidget {
  const ScanDiterimaScreen({super.key});
  @override
  ConsumerState<ScanDiterimaScreen> createState() => _ScanDiterimaScreenState();
}

class _ScanDiterimaScreenState extends ConsumerState<ScanDiterimaScreen> {
  final _namaC = TextEditingController();
  final _catatanC = TextEditingController();
  bool _submitting = false;
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
      appBar: AppBar(
        title: const Text('Scan Diterima'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_tx == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Tekan "SCAN" untuk memulai', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('Scan barcode resi yang akan diterima', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No. Resi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                              Row(
                                children: [
                                  Expanded(child: Text(_tx!.noResi, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1))),
                                  ResiCopyButton(resi: _tx!.noResi),
                                ],
                              ),
                              const Divider(),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: _row('Penerima', _tx!.penerimaName),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: _row('Pengirim', _tx!.pengirimName),
                                ),
                              ),
                              _row('Paket', '${_tx!.beratLabel}, ${_tx!.koliLabel}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _namaC,
                        decoration: const InputDecoration(
                          labelText: 'Nama Penerima *',
                          hintText: 'Masukkan nama penerima',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _catatanC,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          hintText: 'Kondisi barang, dll',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _tx == null
              ? SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('SCAN'),
                  ),
                )
              : Row(
                  children: [
                    GestureDetector(
                      onLongPress: () { setState(() { _tx = null; _namaC.clear(); _catatanC.clear(); }); },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close, color: Colors.red.shade700, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _submitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('KONFIRMASI'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerDialog.show(context, label: 'Scan barcode resi yang diterima');
    if (code == null || code.isEmpty) return;

    try {
      final res = await ApiService().get('${ApiConstants.track}/$code');
      final tx = Transaction.fromJson(res.data as Map<String, dynamic>);

      SoundPlayer.instance.playScan();
      setState(() => _tx = tx);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resi $code tidak ditemukan')));
      }
    }
  }

  Future<void> _confirm() async {
    if (_namaC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama Penerima wajib diisi'), backgroundColor: AppTheme.error));
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.batchUpdateStatus(
        noResiList: [_tx!.noResi],
        statusBaru: 'diterima',
        namaPenerima: _namaC.text.trim(),
        catatan: _catatanC.text.trim().isNotEmpty ? _catatanC.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Paket telah diterima'), backgroundColor: Colors.green));
        SoundPlayer.instance.playSuccess();
        setState(() { _tx = null; _namaC.clear(); _catatanC.clear(); });
      }
    } catch (e) {
      SoundPlayer.instance.playError();
      if (mounted) {
        final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Gagal') : 'Gagal memperbarui status';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    } finally {
      setState(() => _submitting = false);
    }
  }
}
