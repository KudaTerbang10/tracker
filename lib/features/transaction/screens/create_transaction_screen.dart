import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/barcode_widget.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/sound_player.dart';
import '../../../shared/utils/ongkir_service.dart';
import '../../auth/providers/auth_provider.dart';

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
  final _penerimaKecC = TextEditingController();
  final _beratC = TextEditingController();
  final _koliC = TextEditingController(text: '1');
  final _biayaC = TextEditingController();

  bool _submitting = false;
  Transaction? _createdTransaction;
  String? _kotaTujuan;
  OngkirResult? _ongkirResult;
  bool _originFound = true;
  int _autocompleteResetKey = 0;
  bool _isFormattingAddr = false;

  String? _originApiKota() {
    final user = ref.read(authProvider).user;
    final cabangKota = user?.lokasi?['kota'] as String?;
    return OngkirService.cabangToKota(cabangKota);
  }

  void _calcOngkir() {
    final asal = _originApiKota();
    final tujuan = _kotaTujuan;
    final beratText = _beratC.text.trim();
    if (asal == null) { setState(() { _originFound = false; _ongkirResult = null; }); return; }
    if (tujuan == null || tujuan.isEmpty || beratText.isEmpty) { setState(() { _ongkirResult = null; }); return; }
    final berat = double.tryParse(beratText);
    if (berat == null || berat <= 0) { setState(() { _ongkirResult = null; }); return; }
    final result = OngkirService.hitung(asal, tujuan, berat);
    setState(() {
      _originFound = true;
      _ongkirResult = result;
      if (result != null) _biayaC.text = result.total.toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _beratC.addListener(_calcOngkir);
    _pengirimNameC.addListener(_formatPengirimName);
    _penerimaNameC.addListener(_formatPenerimaName);
    _pengirimAddrC.addListener(_formatPengirimAddr);
    _penerimaAddrC.addListener(_formatPenerimaAddr);
  }

  void _formatPengirimAddr() {
    if (_isFormattingAddr) return;
    _isFormattingAddr = true;
    final formatted = _formatAddress(_pengirimAddrC.text);
    if (formatted != _pengirimAddrC.text) {
      _pengirimAddrC.text = formatted;
      _pengirimAddrC.selection = TextSelection.collapsed(offset: formatted.length);
    }
    _isFormattingAddr = false;
  }

  void _formatPenerimaAddr() {
    if (_isFormattingAddr) return;
    _isFormattingAddr = true;
    final formatted = _formatAddress(_penerimaAddrC.text);
    if (formatted != _penerimaAddrC.text) {
      _penerimaAddrC.text = formatted;
      _penerimaAddrC.selection = TextSelection.collapsed(offset: formatted.length);
    }
    _isFormattingAddr = false;
  }

  void _formatPengirimName() {
    if (_isFormattingAddr) return;
    _isFormattingAddr = true;
    final formatted = _formatAddress(_pengirimNameC.text);
    if (formatted != _pengirimNameC.text) {
      _pengirimNameC.text = formatted;
      _pengirimNameC.selection = TextSelection.collapsed(offset: formatted.length);
    }
    _isFormattingAddr = false;
  }

  void _formatPenerimaName() {
    if (_isFormattingAddr) return;
    _isFormattingAddr = true;
    final formatted = _formatAddress(_penerimaNameC.text);
    if (formatted != _penerimaNameC.text) {
      _penerimaNameC.text = formatted;
      _penerimaNameC.selection = TextSelection.collapsed(offset: formatted.length);
    }
    _isFormattingAddr = false;
  }

  static String _formatAddress(String text) {
    final words = text.split(' ');
    final formatted = words.map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      if (lower == 'rt' || lower == 'rw') return lower.toUpperCase();
      final match = RegExp(r'^(rt|rw)(\d+)$', caseSensitive: false).firstMatch(w);
      if (match != null) return '${match.group(1)!.toUpperCase()}${match.group(2)}';
      // biarkan ALL UPPERCASE (PT, CV, dll), title-case-kan sisanya
      if (!w.contains(RegExp(r'[a-z]'))) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
    return formatted;
  }

  @override
  void dispose() {
    _beratC.removeListener(_calcOngkir);
    _pengirimNameC.removeListener(_formatPengirimName);
    _penerimaNameC.removeListener(_formatPenerimaName);
    _pengirimAddrC.removeListener(_formatPengirimAddr);
    _penerimaAddrC.removeListener(_formatPenerimaAddr);
    _pengirimNameC.dispose();
    _pengirimPhoneC.dispose();
    _pengirimAddrC.dispose();
    _penerimaNameC.dispose();
    _penerimaPhoneC.dispose();
    _penerimaAddrC.dispose();
    _penerimaKecC.dispose();
    _beratC.dispose();
    _koliC.dispose();
    _biayaC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCreated = _createdTransaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasCreated ? 'Transaksi Berhasil' : 'Transaksi Baru'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: hasCreated
          ? _buildSuccess()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Penerima Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('DATA PENERIMA', Icons.person_pin_rounded),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _penerimaNameC,
                              decoration: const InputDecoration(labelText: 'Nama Penerima *', prefixIcon: Icon(Icons.person_outline_rounded)),
                              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _penerimaPhoneC,
                              decoration: const InputDecoration(labelText: 'Kontak Penerima *', prefixIcon: Icon(Icons.phone_outlined)),
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _penerimaAddrC,
                              decoration: const InputDecoration(labelText: 'Alamat Lengkap Penerima *', prefixIcon: Icon(Icons.location_on_outlined)),
                              maxLines: 2,
                              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            Autocomplete<String>(
                              key: ValueKey(_autocompleteResetKey),
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) return OngkirService.availableCities;
                                return OngkirService.availableCities.where((c) =>
                                  c.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                                );
                              },
                              initialValue: _kotaTujuan == null ? null : TextEditingValue(text: _kotaTujuan!),
                              onSelected: (v) => setState(() { _kotaTujuan = v; _calcOngkir(); }),
                              displayStringForOption: (v) => v,
                              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Kota Tujuan *',
                                    prefixIcon: Icon(Icons.location_city_rounded),
                                  ),
                                  validator: (v) => _kotaTujuan == null ? 'Pilih kota tujuan' : null,
                                );
                              },
                            ),
                            if (!_originFound) ...[
                              const SizedBox(height: 8),
                              const Text('Kota asal tidak dapat ditentukan — atur di data cabang', style: TextStyle(color: Colors.red, fontSize: 11)),
                            ],
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _penerimaKecC,
                              decoration: const InputDecoration(
                                labelText: 'Kecamatan *',
                                prefixIcon: Icon(Icons.map_rounded),
                                hintText: 'Contoh: Margahayu',
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pengirim Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('DATA PENGIRIM', Icons.send_rounded),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _pengirimNameC,
                              decoration: const InputDecoration(labelText: 'Nama Pengirim *', prefixIcon: Icon(Icons.person_outline_rounded)),
                              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pengirimPhoneC,
                              decoration: const InputDecoration(labelText: 'Kontak Pengirim *', prefixIcon: Icon(Icons.phone_outlined)),
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pengirimAddrC,
                              decoration: const InputDecoration(labelText: 'Alamat Lengkap Pengirim *', prefixIcon: Icon(Icons.location_on_outlined)),
                              maxLines: 2,
                              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Paket Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('RINCIAN BARANG KIRIMAN', Icons.inventory_2_rounded),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _beratC,
                                    decoration: const InputDecoration(labelText: 'Berat *', prefixIcon: Icon(Icons.scale_rounded), suffixText: 'kg'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (v?.isEmpty ?? true) ? 'Wajib' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _koliC,
                                    decoration: const InputDecoration(labelText: 'Jumlah Koli *', prefixIcon: Icon(Icons.apps_rounded)),
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (v?.isEmpty ?? true) ? 'Wajib' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _biayaC,
                              decoration: const InputDecoration(labelText: 'Biaya Kirim', prefixIcon: Icon(Icons.payments_rounded), prefixText: 'Rp '),
                              keyboardType: TextInputType.number,
                            ),
                            if (_ongkirResult != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE0E7FF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Estimasi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        Text(_ongkirResult!.est, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('5 kg pertama', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_ongkirResult!.min),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('/kg selanjutnya', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_ongkirResult!.perkg),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                        Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_ongkirResult!.total),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.print_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('Cetak Resi & Buat Transaksi'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 54, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              'Detail pengiriman barang telah disimpan ke sistem.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Ticket Card Layout
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'NOMOR RESI PENGIRIMAN',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 16),
                    BarcodeDisplay(data: _createdTransaction!.noResi),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => LabelPrinter.printBarcodeLabel(
                          data: _createdTransaction!.noResi,
                          pengirim: _createdTransaction!.pengirim,
                          penerima: _createdTransaction!.penerima,
                          paket: _createdTransaction!.paket,
                          createdAt: _createdTransaction!.createdAt,
                          asal: _createdTransaction!.createdBy['cabang_name']?.toString() ??
                              _createdTransaction!.createdBy['konter_name']?.toString() ??
                              _createdTransaction!.createdBy['gudang_name']?.toString(),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Cetak Resi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _reset();
                    _createdTransaction = null;
                  });
                },
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Buat Transaksi Baru'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Kembali ke Dashboard'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
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
    _penerimaKecC.clear();
    _beratC.clear();
    _koliC.text = '1';
    _biayaC.clear();
    setState(() {
      _kotaTujuan = null;
      _ongkirResult = null;
      _autocompleteResetKey++;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final tx = await repo.create(
        pengirim: { 'name': _pengirimNameC.text.trim(), 'phone': _pengirimPhoneC.text.trim(), 'address': _pengirimAddrC.text.trim() },
        penerima: {
          'name': _penerimaNameC.text.trim(),
          'phone': _penerimaPhoneC.text.trim(),
          'address': _penerimaAddrC.text.trim(),
          'kecamatan': _penerimaKecC.text.trim(),
          'kota': _kotaTujuan ?? '',
        },
        paket: {
          'berat_kg': double.tryParse(_beratC.text) ?? 0,
          'jumlah_koli': int.tryParse(_koliC.text) ?? 1,
          'biaya_kirim': double.tryParse(_biayaC.text) ?? 0,
        },
      );
      SoundPlayer.instance.playSuccess();
      setState(() => _createdTransaction = tx);
    } catch (e) {
      SoundPlayer.instance.playError();
      if (mounted) {
        final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Gagal membuat transaksi') : 'Gagal membuat transaksi';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    } finally {
      setState(() => _submitting = false);
    }
  }
}
