import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/barcode_widget.dart';
import '../../../shared/utils/label_printer.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  const CreateTransactionScreen({super.key});
  @override
  ConsumerState<CreateTransactionScreen> createState() => _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends ConsumerState<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _pengirimNameC = TextEditingController();
  final _pengirimPhoneC = TextEditingController();
  final _pengirimAddrC = TextEditingController();
  final _penerimaNameC = TextEditingController();
  final _penerimaPhoneC = TextEditingController();
  final _penerimaAddrC = TextEditingController();
  final _beratC = TextEditingController();
  final _koliC = TextEditingController(text: '1');
  final _biayaC = TextEditingController();

  bool _submitting = false;
  Transaction? _createdTransaction;

  @override
  void dispose() {
    _pengirimNameC.dispose();
    _pengirimPhoneC.dispose();
    _pengirimAddrC.dispose();
    _penerimaNameC.dispose();
    _penerimaPhoneC.dispose();
    _penerimaAddrC.dispose();
    _beratC.dispose();
    _koliC.dispose();
    _biayaC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_createdTransaction != null ? 'Transaksi Berhasil' : 'Transaksi Baru'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _createdTransaction != null
          ? _buildSuccess()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Data Penerima'),
                              const SizedBox(height: 8),
                              TextFormField(controller: _penerimaNameC, decoration: const InputDecoration(labelText: 'Nama Penerima *', prefixIcon: Icon(Icons.person)), validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null),
                              const SizedBox(height: 12),
                              TextFormField(controller: _penerimaPhoneC, decoration: const InputDecoration(labelText: 'Kontak Penerima *', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone, validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null),
                              const SizedBox(height: 12),
                              TextFormField(controller: _penerimaAddrC, decoration: const InputDecoration(labelText: 'Alamat Penerima *', prefixIcon: Icon(Icons.location_on)), maxLines: 2, validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Data Pengirim'),
                              const SizedBox(height: 8),
                              TextFormField(controller: _pengirimNameC, decoration: const InputDecoration(labelText: 'Nama Pengirim *', prefixIcon: Icon(Icons.person)), validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null),
                              const SizedBox(height: 12),
                              TextFormField(controller: _pengirimPhoneC, decoration: const InputDecoration(labelText: 'Kontak Pengirim *', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone, validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null),
                              const SizedBox(height: 12),
                              TextFormField(controller: _pengirimAddrC, decoration: const InputDecoration(labelText: 'Alamat Pengirim *', prefixIcon: Icon(Icons.location_on)), maxLines: 2, validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    _sectionTitle('Data Paket'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _beratC, decoration: const InputDecoration(labelText: 'Berat (kg) *', prefixIcon: Icon(Icons.scale), suffixText: 'kg'), keyboardType: TextInputType.number, validator: (v) => (v?.isEmpty ?? true) ? 'Wajib' : null)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _koliC, decoration: const InputDecoration(labelText: 'Jumlah Koli *', prefixIcon: Icon(Icons.inventory_2)), keyboardType: TextInputType.number, validator: (v) => (v?.isEmpty ?? true) ? 'Wajib' : null)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _biayaC, decoration: const InputDecoration(labelText: 'Biaya Kirim', prefixIcon: Icon(Icons.payments), prefixText: 'Rp '), keyboardType: TextInputType.number),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Buat Transaksi & Cetak Resi'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary));
  }

  Widget _buildSuccess() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('Transaksi Berhasil!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No. Resi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _createdTransaction!.noResi));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No. Resi disalin'), duration: Duration(seconds: 2)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.copy, size: 14),
                                SizedBox(width: 4),
                                Text('Salin', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_createdTransaction!.noResi, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 16),
                    BarcodeDisplay(data: _createdTransaction!.noResi),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
                onPressed: () => LabelPrinter.printBarcodeLabel(
                  data: _createdTransaction!.noResi,
                  pengirim: _createdTransaction!.pengirim,
                  penerima: _createdTransaction!.penerima,
                  paket: _createdTransaction!.paket,
                ),
                icon: const Icon(Icons.print),
                label: const Text('Cetak Resi'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () { setState(() { _reset(); _createdTransaction = null; }); },
                child: const Text('Buat Transaksi Lagi'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Kembali ke Dashboard')),
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    _pengirimNameC.clear();
    _pengirimPhoneC.clear();
    _pengirimAddrC.clear();
    _penerimaNameC.clear();
    _penerimaPhoneC.clear();
    _penerimaAddrC.clear();
    _beratC.clear();
    _koliC.text = '1';
    _biayaC.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final tx = await repo.create(
        pengirim: { 'name': _pengirimNameC.text.trim(), 'phone': _pengirimPhoneC.text.trim(), 'address': _pengirimAddrC.text.trim() },
        penerima: { 'name': _penerimaNameC.text.trim(), 'phone': _penerimaPhoneC.text.trim(), 'address': _penerimaAddrC.text.trim() },
        paket: {
          'berat_kg': double.tryParse(_beratC.text) ?? 0,
          'jumlah_koli': int.tryParse(_koliC.text) ?? 1,
          'biaya_kirim': double.tryParse(_biayaC.text) ?? 0,
        },
      );
      setState(() => _createdTransaction = tx);
    } catch (e) {
      if (mounted) {
        final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Gagal membuat transaksi') : 'Gagal membuat transaksi';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    } finally {
      setState(() => _submitting = false);
    }
  }
}
