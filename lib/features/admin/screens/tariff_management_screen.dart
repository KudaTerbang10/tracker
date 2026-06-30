import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/utils/capitalize_formatter.dart';
import '../../../shared/utils/sound_player.dart';

class TariffItem {
  final String id;
  final String key;
  final String asal;
  final String tujuan;
  final int min;
  final int perkg;
  final String est;

  TariffItem({required this.id, required this.key, required this.asal, required this.tujuan, required this.min, required this.perkg, required this.est});

  String get asalCapitalized => asal.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  String get tujuanCapitalized => tujuan.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  factory TariffItem.fromJson(Map<String, dynamic> json) => TariffItem(
    id: json['tariff_id'] as String? ?? json['_id'] as String,
    key: json['key'] as String,
    asal: json['asal'] as String,
    tujuan: json['tujuan'] as String,
    min: json['min'] as int,
    perkg: json['perkg'] as int,
    est: json['est'] as String,
  );
}

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

class TariffManagementScreen extends ConsumerStatefulWidget {
  const TariffManagementScreen({super.key});
  @override
  ConsumerState<TariffManagementScreen> createState() => _TariffManagementScreenState();
}

class _TariffManagementScreenState extends ConsumerState<TariffManagementScreen> {
  final _asalC = TextEditingController();
  final _tujuanC = TextEditingController();
  final _scrollC = ScrollController();
  String _asal = '';
  String _tujuan = '';

  List<TariffItem> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollC.addListener(_onScroll);
  }

  @override
  void dispose() {
    _asalC.dispose();
    _tujuanC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollC.position.pixels >= _scrollC.position.maxScrollExtent - 200 && !_loading && _hasMore) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final params = <String, dynamic>{'page': _page, 'limit': 20};
      if (_asal.isNotEmpty) params['asal'] = _asal;
      if (_tujuan.isNotEmpty) params['tujuan'] = _tujuan;

      final res = await ApiService().get('/tariffs', query: params);
      final data = res.data['data'] as List<dynamic>;
      final totalPages = res.data['totalPages'] as int;
      final newItems = data.map((e) => TariffItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      setState(() {
        _items.addAll(newItems);
        _page++;
        _hasMore = _page <= totalPages;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _items = [];
      _page = 1;
      _hasMore = true;
    });
    await _fetch();
  }

  void _onAsalChanged(String v) {
    _asal = v;
    _reset();
  }

  void _onTujuanChanged(String v) {
    _tujuan = v;
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Tarif'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/dashboard/tariffs-bulk'),
            icon: const Icon(Icons.table_rows_rounded, size: 18),
            label: const Text('Input Massal', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showAddForm(context),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Tidak ada tarif'))
                : ListView.builder(
                    controller: _scrollC,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final t = _items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () => _showEditForm(context, ref, t),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  radius: 24,
                                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF3B82F6), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${t.asalCapitalized} → ${t.tujuanCapitalized}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Min: Rp${_formatRupiah(t.min)} | Per kg: Rp${_formatRupiah(t.perkg)} | Estimasi: ${t.est}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              controller: _asalC,
              onChanged: _onAsalChanged,
              decoration: InputDecoration(
                hintText: 'Kota asal...',
                prefixIcon: const Icon(Icons.trip_origin, size: 20),
                suffixIcon: _asal.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _asalC.clear();
                          _onAsalChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: TextField(
              controller: _tujuanC,
              onChanged: _onTujuanChanged,
              decoration: InputDecoration(
                hintText: 'Kota tujuan...',
                prefixIcon: const Icon(Icons.location_on, size: 20),
                suffixIcon: _tujuan.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _tujuanC.clear();
                          _onTujuanChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estRangeSlider(double lower, double upper, void Function(double, double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimasi: ${lower.toInt()} - ${upper.toInt()} Hari',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        RangeSlider(
          values: RangeValues(lower, upper),
          min: 1,
          max: 7,
          divisions: 6,
          labels: RangeLabels('${lower.toInt()} hr', '${upper.toInt()} hr'),
          onChanged: (v) => onChanged(v.start, v.end),
        ),
      ],
    );
  }

  String _estLabel(double lower, double upper) => '${lower.toInt()}-${upper.toInt()} HARI';

  /// Parse "1-3 HARI" → (1, 3). Default (1, 3) if unparseable.
  RangeValues _parseEst(String est) {
    final parts = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(est);
    if (parts == null) return const RangeValues(1, 3);
    final start = int.tryParse(parts.group(1) ?? '1') ?? 1;
    final end = int.tryParse(parts.group(2) ?? '3') ?? 3;
    return RangeValues(start.toDouble(), end.toDouble());
  }

  Future<void> _showAddForm(BuildContext context) async {
    final citiesRes = await ApiService().get(ApiConstants.cabangKota);
    final cities = List<String>.from(
      (citiesRes.data['data'] as List<dynamic>).map((e) => e as String),
    )..sort();

    String? asal;
    String? tujuan;
    final minC = TextEditingController();
    final perkgC = TextEditingController();
    double estLower = 1;
    double estUpper = 3;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Tambah Tarif'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAutocomplete(ctx, cities, 'Kota Asal', Icons.trip_origin, (v) => setDialogState(() => asal = v)),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  optionsBuilder: (value) {
                    if (value.text.isEmpty) return cities;
                    return cities.where((c) => c.toLowerCase().contains(value.text.toLowerCase()));
                  },
                  onSelected: (v) => setDialogState(() => tujuan = v),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    controller.addListener(() {
                      final v = controller.text;
                      if (v.isNotEmpty) tujuan = v;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [CapitalizeWordsFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Kota Tujuan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: minC, decoration: const InputDecoration(labelText: 'Tarif Awal 5 Kg', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory_2)), keyboardType: TextInputType.number, inputFormatters: [_RupiahFormatter()]),
                const SizedBox(height: 12),
                TextField(controller: perkgC, decoration: const InputDecoration(labelText: 'Per kg', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number, inputFormatters: [_RupiahFormatter()]),
                const SizedBox(height: 8),
                _estRangeSlider(estLower, estUpper, (l, u) => setDialogState(() { estLower = l; estUpper = u; })),
              ],
            ),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                    onPressed: () async {
                      if (asal == null || tujuan == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Pilih kota asal dan tujuan')));
                        return;
                      }
                      final min = int.tryParse(minC.text.replaceAll('.', ''));
                      final perkg = int.tryParse(perkgC.text.replaceAll('.', ''));
                      if (min == null || perkg == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Isi semua field dengan benar')));
                        return;
                      }
                      try {
                        await ApiService().post('/tariffs', data: {
                          'asal': asal, 'tujuan': tujuan, 'min': min, 'perkg': perkg, 'est': _estLabel(estLower, estUpper),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _reset();
                        SoundPlayer.instance.playSuccess();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Tarif berhasil ditambahkan'), backgroundColor: Color(0xFF10B981)),
                          );
                        }
                      } on DioException catch (e) {
                        final code = e.response?.statusCode;
                        if (code == 409) {
                          SoundPlayer.instance.playError();
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Rute sudah terdaftar'), backgroundColor: Colors.red),
                          );
                        } else {
                          final msg = e.response?.data?['message'] as String? ?? 'Gagal menambah tarif';
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                    child: const Text('Simpan'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutocomplete(
    BuildContext ctx,
    List<String> cities,
    String label,
    IconData icon,
    void Function(String) onSelected, {
    TextEditingController? controller,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (value) {
        if (value.text.isEmpty) return cities;
        return cities.where((c) => c.toLowerCase().contains(value.text.toLowerCase()));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        final ctrl = controller ?? fieldController;
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [CapitalizeWordsFormatter()],
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon),
          ),
        );
      },
    );
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  void _showEditForm(BuildContext context, WidgetRef ref, TariffItem tariff) {
    final minC = TextEditingController(text: _formatRupiah(tariff.min));
    final perkgC = TextEditingController(text: _formatRupiah(tariff.perkg));
    final range = _parseEst(tariff.est);
    var estLower = range.start;
    var estUpper = range.end;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Edit Tarif'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: Text(tariff.asalCapitalized, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward, size: 20, color: Color(0xFF94A3B8))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: Text(tariff.tujuanCapitalized, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: minC, decoration: const InputDecoration(labelText: 'Tarif Awal 5 Kg', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory_2)), keyboardType: TextInputType.number, inputFormatters: [_RupiahFormatter()]),
                const SizedBox(height: 8),
                TextField(controller: perkgC, decoration: const InputDecoration(labelText: 'Per kg', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number, inputFormatters: [_RupiahFormatter()]),
                const SizedBox(height: 8),
                _estRangeSlider(estLower, estUpper, (l, u) => setDialogState(() { estLower = l; estUpper = u; })),
              ],
            ),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                    onPressed: () async {
                      final min = int.tryParse(minC.text.replaceAll('.', ''));
                      final perkg = int.tryParse(perkgC.text.replaceAll('.', ''));
                      if (min == null || perkg == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Isi semua field dengan benar')));
                        return;
                      }
                      try {
                        await ApiService().put('/tariffs/${tariff.id}', data: {
                          'min': min,
                          'perkg': perkg,
                          'est': _estLabel(estLower, estUpper),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _reset();
                        SoundPlayer.instance.playSuccess();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Tarif berhasil diperbarui'), backgroundColor: Color(0xFF10B981)),
                          );
                        }
                      } catch (e) {
                        final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Error') : 'Error';
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    },
                    child: const Text('Simpan'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
