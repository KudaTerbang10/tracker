import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/ongkir_service.dart';

class CekTarifSection extends StatefulWidget {
  final GlobalKey sectionKey;
  const CekTarifSection({super.key, required this.sectionKey});

  @override
  State<CekTarifSection> createState() => _CekTarifSectionState();
}

class _CekTarifSectionState extends State<CekTarifSection> {
  String? _asal;
  String? _tujuan;
  final _beratC = TextEditingController();
  OngkirResult? _result;
  bool _notFound = false;

  @override
  void dispose() {
    _beratC.dispose();
    super.dispose();
  }

  void _hitung() {
    if (_asal == null || _tujuan == null) { setState(() { _result = null; _notFound = false; }); return; }
    if (_asal == _tujuan) { setState(() { _result = null; _notFound = true; }); return; }

    final beratStr = _beratC.text.replaceAll(',', '.').trim();
    final berat = double.tryParse(beratStr);
    if (berat == null || berat <= 0) { setState(() { _result = null; _notFound = false; }); return; }

    final r = OngkirService.hitung(_asal!, _tujuan!, berat);
    setState(() { _result = r; _notFound = r == null; });
  }

  @override
  Widget build(BuildContext context) {
    final cities = List<String>.from(OngkirService.availableCities)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return KeyedSubtree(
      key: widget.sectionKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text('Cek Tarif Pengiriman', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: AppTheme.primary)),
                const SizedBox(height: 8),
                const Text('Hitung estimasi biaya pengiriman dengan cepat dan transparan', style: TextStyle(color: Color(0xFF64748B), fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _autocomplete(cities, 'Kota Asal', Icons.trip_origin, (v) { setState(() { _asal = v.toLowerCase(); }); _hitung(); }),
                        const SizedBox(height: 16),
                        _autocomplete(cities, 'Kota Tujuan', Icons.location_on, (v) { setState(() { _tujuan = v.toLowerCase(); }); _hitung(); }),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _beratC,
                          decoration: const InputDecoration(labelText: 'Berat (kg)', prefixIcon: Icon(Icons.scale, size: 20)),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitung(),
                        ),
                        if (_result != null) ...[
                          const SizedBox(height: 24),
                          _resultCard(),
                        ] else if (_notFound) ...[
                          const SizedBox(height: 24),
                          _notFoundCard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _autocomplete(List<String> cities, String label, IconData icon, ValueChanged<String> onSelected) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return cities;
        return cities.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (v) { onSelected(v); FocusScope.of(context).unfocus(); },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller, focusNode: focusNode,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
        );
      },
    );
  }

  Widget _resultCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian Tarif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF166534))),
          const SizedBox(height: 16),
          _row('Harga 5 kg pertama', 'Rp${_format(_result!.min)}'),
          const SizedBox(height: 8),
          _row('Per kg berikutnya', 'Rp${_format(_result!.perkg)}'),
          const SizedBox(height: 8),
          _row('Estimasi', _result!.est),
          const Divider(height: 24),
          _row('Total', 'Rp${_format(_result!.total)}', bold: true),
        ],
      ),
    );
  }

  Widget _notFoundCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFED7AA))),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C), size: 20),
          const SizedBox(width: 10),
          const Flexible(child: Text('Rute belum tersedia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFC2410C)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF166534), fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: const Color(0xFF166534))),
    ]);
  }

  String _format(int amount) => amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}
