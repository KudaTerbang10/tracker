import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../shared/utils/sound_player.dart';

class _RupiahFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class _BulkRow {
  final TextEditingController minC;
  final TextEditingController perkgC;
  double estLower = 1;
  double estUpper = 3;

  _BulkRow({String? min, String? perkg, String? est})
      : minC = TextEditingController(text: min ?? ''),
        perkgC = TextEditingController(text: perkg ?? '') {
    if (est != null) {
      final parts = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(est);
      if (parts != null) {
        estLower = double.tryParse(parts.group(1) ?? '1') ?? 1;
        estUpper = double.tryParse(parts.group(2) ?? '3') ?? 3;
      }
    }
  }

  void dispose() {
    minC.dispose();
    perkgC.dispose();
  }
}

class TariffBulkScreen extends StatefulWidget {
  const TariffBulkScreen({super.key});
  @override
  State<TariffBulkScreen> createState() => _TariffBulkScreenState();
}

class _TariffBulkScreenState extends State<TariffBulkScreen> {
  List<String> _allCities = [];
  String? _asal;
  final Map<String, _BulkRow> _rows = {};
  bool _loadingCities = true;
  bool _loadingTariffs = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  final TextEditingController _asalC = TextEditingController();

  @override
  void dispose() {
    _asalC.dispose();
    for (final r in _rows.values) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final res = await ApiService().get(ApiConstants.cabangKota);
      final cities = List<String>.from(
        (res.data['data'] as List<dynamic>).map((e) => e as String),
      )..sort();
      if (mounted) setState(() { _allCities = cities; _loadingCities = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _onAsalSelected(String asal) async {
    _asalC.text = asal;
    for (final r in _rows.values) {
      r.dispose();
    }
    _rows.clear();
    setState(() { _asal = asal; _loadingTariffs = true; });

    try {
      final res = await ApiService().get('/tariffs', query: {'asal': asal, 'limit': '2000'});
      final data = res.data['data'] as List<dynamic>;
      final existing = <String, Map<String, dynamic>>{};
      for (final t in data) {
        final m = Map<String, dynamic>.from(t as Map);
        existing[m['tujuan'] as String] = m;
      }

      final cities = _allCities.where((c) => c.toLowerCase() != asal.toLowerCase()).toList()..sort();
      for (final c in cities) {
        final tarif = existing[c.toLowerCase()];
        _rows[c.toLowerCase()] = _BulkRow(
          min: tarif != null ? _formatRupiahInt(tarif['min'] as int) : null,
          perkg: tarif != null ? _formatRupiahInt(tarif['perkg'] as int) : null,
          est: tarif?['est'] as String?,
        );
      }

      if (mounted) setState(() => _loadingTariffs = false);
    } catch (_) {
      if (mounted) setState(() => _loadingTariffs = false);
    }
  }

  Future<void> _saveAll() async {
    if (_asal == null) return;
    final tariffs = <Map<String, dynamic>>[];
    for (final entry in _rows.entries) {
      final tujuan = entry.key;
      final row = entry.value;
      final min = int.tryParse(row.minC.text.replaceAll('.', ''));
      final perkg = int.tryParse(row.perkgC.text.replaceAll('.', ''));
      if (min == null || perkg == null) continue;
      final est = '${row.estLower.toInt()}-${row.estUpper.toInt()} HARI';
      tariffs.add({
        'key': '${_asal!.toLowerCase()}|$tujuan',
        'asal': _asal!.toLowerCase(),
        'tujuan': tujuan,
        'min': min,
        'perkg': perkg,
        'est': est,
      });
    }

    if (tariffs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada tarif yang diisi')));
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiService().post('/tariffs/import', data: {'tariffs': tariffs});
      final count = res.data['count'] as int? ?? tariffs.length;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil menyimpan $count tarif'), backgroundColor: const Color(0xFF10B981)),
        );
        SoundPlayer.instance.playSuccess();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Gagal') : 'Gagal';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatRupiahInt(int amount) {
    return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Tarif Massal'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: _asal != null
            ? [
                TextButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan Semua'),
                ),
              ]
            : null,
      ),
      body: _loadingCities
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildAsalPicker(),
                if (_loadingTariffs)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (_asal != null)
                  Expanded(child: _buildBulkList()),
              ],
            ),
    );
  }

  Widget _buildAsalPicker() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _asal != null
          ? TextField(
              controller: _asalC,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Kota Asal',
                prefixIcon: const Icon(Icons.trip_origin),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _asalC.clear();
                    for (final r in _rows.values) { r.dispose(); }
                    _rows.clear();
                    setState(() => _asal = null);
                  },
                ),
              ),
            )
          : Autocomplete<String>(
              optionsBuilder: (value) {
                if (value.text.isEmpty) return _allCities;
                return _allCities.where((c) => c.toLowerCase().contains(value.text.toLowerCase()));
              },
              onSelected: _onAsalSelected,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Pilih Kota Asal',
                    hintText: 'Ketik nama kota...',
                    prefixIcon: const Icon(Icons.trip_origin),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBulkList() {
    if (_rows.isEmpty) return const Center(child: Text('Tidak ada kota tujuan'));
    final cities = _allCities.where((c) => c.toLowerCase() != _asal!.toLowerCase()).toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: cities.length,
      itemBuilder: (_, i) {
        final city = cities[i];
        final cityLower = city.toLowerCase();
        final row = _rows[cityLower]!;
        final isFilled = row.minC.text.isNotEmpty || row.perkgC.text.isNotEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isFilled ? const Color(0xFFF0FDF4) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFilled ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        city,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isFilled ? const Color(0xFF059669) : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_asal!} → $city',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const Spacer(),
                    Text(
                      '${row.estLower.toInt()}-${row.estUpper.toInt()} hr',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, size: 16),
                      onPressed: () => _showEstSlider(cityLower, row),
                      tooltip: 'Estimasi hari',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: row.minC,
                        decoration: const InputDecoration(
                          labelText: 'Min 5kg',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_RupiahFormatter()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: row.perkgC,
                        decoration: const InputDecoration(
                          labelText: 'Per kg',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_RupiahFormatter()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEstSlider(String cityLower, _BulkRow row) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Estimasi Hari'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${row.estLower.toInt()} - ${row.estUpper.toInt()} Hari',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              RangeSlider(
                values: RangeValues(row.estLower, row.estUpper),
                min: 1,
                max: 7,
                divisions: 6,
                labels: RangeLabels('${row.estLower.toInt()} hr', '${row.estUpper.toInt()} hr'),
                onChanged: (v) => setDialogState(() {
                  row.estLower = v.start;
                  row.estUpper = v.end;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
