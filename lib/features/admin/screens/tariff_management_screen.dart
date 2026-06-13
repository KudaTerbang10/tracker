import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/remote/api_service.dart';
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

final _tariffsProvider = FutureProvider.autoDispose<List<TariffItem>>((ref) async {
  final res = await ApiService().get('/tariffs');
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => TariffItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

class TariffManagementScreen extends ConsumerStatefulWidget {
  const TariffManagementScreen({super.key});
  @override
  ConsumerState<TariffManagementScreen> createState() => _TariffManagementScreenState();
}

class _TariffManagementScreenState extends ConsumerState<TariffManagementScreen> {
  final _asalC = TextEditingController();
  final _tujuanC = TextEditingController();
  String _asal = '';
  String _tujuan = '';

  @override
  void dispose() {
    _asalC.dispose();
    _tujuanC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_tariffsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Tarif'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (tariffs) {
                final qAsal = _asal.toLowerCase();
                final qTujuan = _tujuan.toLowerCase();
                final filtered = tariffs.where((t) {
                  final matchAsal = qAsal.isEmpty || t.asal.toLowerCase().contains(qAsal);
                  final matchTujuan = qTujuan.isEmpty || t.tujuan.toLowerCase().contains(qTujuan);
                  return matchAsal && matchTujuan;
                }).toList();

                return filtered.isEmpty
                    ? const Center(child: Text('Tidak ada tarif'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final t = filtered[i];
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
              onChanged: (v) => setState(() => _asal = v),
              decoration: InputDecoration(
                hintText: 'Kota asal...',
                prefixIcon: const Icon(Icons.trip_origin, size: 20),
                suffixIcon: _asal.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _asalC.clear();
                          setState(() => _asal = '');
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
              onChanged: (v) => setState(() => _tujuan = v),
              decoration: InputDecoration(
                hintText: 'Kota tujuan...',
                prefixIcon: const Icon(Icons.location_on, size: 20),
                suffixIcon: _tujuan.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _tujuanC.clear();
                          setState(() => _tujuan = '');
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

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  void _showEditForm(BuildContext context, WidgetRef ref, TariffItem tariff) {
    final minC = TextEditingController(text: tariff.min.toString());
    final perkgC = TextEditingController(text: tariff.perkg.toString());
    final estC = TextEditingController(text: tariff.est);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Edit Tarif: ${tariff.asalCapitalized} → ${tariff.tujuanCapitalized}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: minC, decoration: const InputDecoration(labelText: 'Min (5kg)'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: perkgC, decoration: const InputDecoration(labelText: 'Per kg'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: estC, decoration: const InputDecoration(labelText: 'Estimasi (contoh: 1-3 HARI)')),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final min = int.tryParse(minC.text);
              final perkg = int.tryParse(perkgC.text);
              final est = estC.text.trim();
              if (min == null || perkg == null || est.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi semua field dengan benar')));
                return;
              }
              try {
                await ApiService().put('/tariffs/${tariff.id}', data: {
                  'min': min,
                  'perkg': perkg,
                  'est': est,
                });
                Navigator.pop(ctx);
                ref.invalidate(_tariffsProvider);
                SoundPlayer.instance.playSuccess();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Tarif berhasil diperbarui'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Error') : 'Error';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            child: const Text('Simpan'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
        ],
      ),
    );
  }
}
