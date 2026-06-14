import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/ongkir_service.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _resiC = TextEditingController();

  @override
  void dispose() {
    _resiC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cities = List<String>.from(OngkirService.availableCities)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF2F6), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Brand Header
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onLongPress: () => context.go('/login'),
                      child: Ink(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/pics/hiralogo.webp',
                            width: 72,
                            height: 72,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hira Express',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lacak kiriman Anda secara real-time',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Tracking Card
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lacak Pengiriman',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _resiC,
                            decoration: InputDecoration(
                              labelText: 'Masukkan No. Resi',
                              hintText: 'Contoh: CKG-20270710-0002',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppTheme.primary,
                              ),
                              suffixIcon: Container(
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: _scanBarcode,
                                ),
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            onFieldSubmitted: (_) => _track(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _track,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.track_changes_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Lacak'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCekTarif(context, cities),
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          label: const Text('Cek Tarif'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                            backgroundColor: Colors.white.withValues(alpha: 0.6),
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                            backgroundColor: Colors.white.withValues(alpha: 0.6),
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCekTarif(BuildContext context, List<String> cities) {
    String? asal;
    String? tujuan;
    final beratC = TextEditingController();
    OngkirResult? result;
    var notFound = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final hitung = () {
              if (asal == null || tujuan == null || asal == tujuan) {
                setDialogState(() { result = null; notFound = false; });
                return;
              }
              final berat = double.tryParse(beratC.text);
              if (berat == null || berat <= 0) {
                setDialogState(() { result = null; notFound = false; });
                return;
              }
              final r = OngkirService.hitung(asal!, tujuan!, berat);
              setDialogState(() {
                result = r;
                notFound = r == null;
              });
            };

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Cek Tarif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return cities;
                        return cities.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (v) => setDialogState(() { asal = v.toLowerCase(); hitung(); }),
                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onSubmitted: (_) => onSubmitted(),
                          decoration: const InputDecoration(labelText: 'Kota Asal', prefixIcon: Icon(Icons.trip_origin, size: 20)),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return cities;
                        return cities.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (v) => setDialogState(() { tujuan = v.toLowerCase(); hitung(); }),
                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onSubmitted: (_) => onSubmitted(),
                          decoration: const InputDecoration(labelText: 'Kota Tujuan', prefixIcon: Icon(Icons.location_on, size: 20)),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: beratC,
                      decoration: const InputDecoration(
                        labelText: 'Berat (kg)',
                        prefixIcon: Icon(Icons.scale, size: 20),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => hitung(),
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rincian Tarif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF166534))),
                            const SizedBox(height: 12),
                            _rincianRow('Harga 5 kg pertama', 'Rp${_format(result!.min)}'),
                            const SizedBox(height: 6),
                            _rincianRow('Per kg berikutnya', 'Rp${_format(result!.perkg)}'),
                            const SizedBox(height: 6),
                            _rincianRow('Estimasi', result!.est),
                            const Divider(height: 20),
                            _rincianRow('Total', 'Rp${_format(result!.total)}', bold: true),
                          ],
                        ),
                      ),
                    ] else if (notFound) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFFED7AA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C), size: 20),
                            SizedBox(width: 10),
                            Text('Rute belum tersedia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFC2410C))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('TUTUP')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _rincianRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF166534), fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: const Color(0xFF166534))),
      ],
    );
  }

  String _format(int amount) {
    return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerDialog.show(context);
    if (code != null && code.isNotEmpty) {
      _resiC.text = code.toUpperCase();
      _track();
    }
  }

  void _track() {
    final resi = _resiC.text.trim().toUpperCase();
    if (resi.isEmpty) return;
    context.go('/track/$resi');
  }
}
