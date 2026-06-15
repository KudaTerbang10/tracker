import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../shared/utils/sound_player.dart';
import '../../../shared/widgets/location_picker.dart';

class Cabang {
  final String id;
  final String kode;
  final String name;
  final String address;
  final String phone;
  final String kota;
  final bool isActive;
  final double? latitude;
  final double? longitude;

  Cabang({required this.id, required this.kode, required this.name, required this.address, required this.phone, required this.kota, required this.isActive, this.latitude, this.longitude});

  factory Cabang.fromJson(Map<String, dynamic> json) => Cabang(
    id: json['cabang_id'] as String? ?? json['_id'] as String,
    kode: json['kode'] as String,
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    kota: json['kota'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? true,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  String get latLngString {
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
    }
    return '';
  }
}

final _cabangsProvider = FutureProvider.autoDispose<List<Cabang>>((ref) async {
  final res = await ApiService().get('/cabangs');
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => Cabang.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

class CabangManagementScreen extends ConsumerStatefulWidget {
  const CabangManagementScreen({super.key});
  @override
  ConsumerState<CabangManagementScreen> createState() => _CabangManagementScreenState();
}

class _CabangManagementScreenState extends ConsumerState<CabangManagementScreen> {
  final _searchC = TextEditingController();
  String _search = '';
  String _kotaFilter = 'all';

  List<Map<String, String>> _buildFilters(List<Cabang> cabangs) {
    final counts = <String, int>{};
    for (final c in cabangs) {
      final k = c.kota.startsWith('Jakarta') ? 'jakarta' : c.kota;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final filters = <Map<String, String>>[];
    filters.add({'key': 'all', 'label': 'Semua'});
    if ((counts['jakarta'] ?? 0) > 0) filters.add({'key': 'jakarta', 'label': 'Jakarta'});
    for (final entry in counts.entries) {
      if (entry.key == 'jakarta') continue;
      if (entry.value > 1) filters.add({'key': entry.key, 'label': entry.key});
    }
    filters.add({'key': 'lainnya', 'label': 'Kota Lainnya'});
    filters.add({'key': 'nonaktif', 'label': 'Nonaktif'});
    return filters;
  }

  bool _matchKotaFilter(Cabang c, String filter, Map<String, int> counts) {
    if (filter == 'nonaktif') return !c.isActive;
    if (!c.isActive) return false;
    if (filter == 'all') return true;
    if (filter == 'jakarta') return c.kota.startsWith('Jakarta');
    if (filter == 'lainnya') {
      final k = c.kota.startsWith('Jakarta') ? 'jakarta' : c.kota;
      return (counts[k] ?? 0) <= 1;
    }
    return c.kota == filter;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_cabangsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Cabang'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(context, ref),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (cabangs) {
                final counts = <String, int>{};
                for (final c in cabangs) {
                  final k = c.kota.startsWith('Jakarta') ? 'jakarta' : c.kota;
                  counts[k] = (counts[k] ?? 0) + 1;
                }
                final filters = _buildFilters(cabangs);
                final filterCounts = <String, int>{
                  'all': cabangs.length,
                  'nonaktif': cabangs.where((c) => !c.isActive).length,
                  'jakarta': cabangs.where((c) => c.kota.startsWith('Jakarta')).length,
                  'lainnya': cabangs.where((c) {
                    final k = c.kota.startsWith('Jakarta') ? 'jakarta' : c.kota;
                    return (counts[k] ?? 0) <= 1 && c.isActive;
                  }).length,
                };
                for (final entry in counts.entries) {
                  if (entry.key != 'jakarta' && entry.value > 1) {
                    filterCounts[entry.key] = entry.value;
                  }
                }
                final q = _search.toLowerCase();
                final filtered = cabangs.where((c) {
                  if (q.isEmpty) return true;
                  return c.kode.toLowerCase().contains(q) ||
                      c.name.toLowerCase().contains(q) ||
                      c.kota.toLowerCase().contains(q);
                }).where((c) => _matchKotaFilter(c, _kotaFilter, counts)).toList();

                return Column(
                  children: [
                    _buildFilterChips(filters, filterCounts),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Tidak ada cabang'))
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                           final c = filtered[i];
                           final avatarColor = c.isActive ? const Color(0xFF3B82F6) : const Color(0xFFEF4444);
                           return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                              child: InkWell(
                               onTap: () => _showForm(context, ref, cabang: c),
                               onLongPress: () => _confirmDelete(context, ref, c),
                               borderRadius: BorderRadius.circular(16),
                               child: Padding(
                                 padding: const EdgeInsets.all(14),
                                 child: Opacity(
                                   opacity: c.isActive ? 1.0 : 0.5,
                                   child: Row(
                                  children: [
                                     CircleAvatar(
                                       backgroundColor: avatarColor.withValues(alpha: 0.1),
                                       radius: 24,
                                       child: Icon(Icons.business_rounded, color: avatarColor, size: 22),
                                     ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15), width: 0.5),
                                                ),
                                                child: Text(
                                                  c.kode,
                                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  c.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(c.address, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (c.kota.isNotEmpty) ...[
                                                Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                                                const SizedBox(width: 3),
                                                Flexible(child: Text(c.kota, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                                const SizedBox(width: 12),
                                              ],
                                              Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade400),
                                              const SizedBox(width: 3),
                                              Flexible(child: Text(c.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                        },
                      ),
                    ),
                  ],
                );   // close inner Column
              },     // close data callback
            ),       // close async.when
          ),         // close Expanded (outer)
        ],           // close Column children
      ),             // close Column
    );               // close Scaffold body
  }                  // close build

  Widget _buildFilterChips(List<Map<String, String>> filters, Map<String, int> filterCounts) {
    return SizedBox(
      height: 44,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < filters.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                () {
                  final f = filters[i];
                  final selected = _kotaFilter == f['key'];
                  final count = filterCounts[f['key']] ?? 0;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(f['label']!),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _kotaFilter = f['key']!),
                    selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    checkmarkColor: const Color(0xFF3B82F6),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchC,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Cari kode, nama, atau kota...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchC.clear();
                      setState(() => _search = '');
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
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, {Cabang? cabang}) {
    final isEdit = cabang != null;
    final kodeC = TextEditingController(text: cabang?.kode ?? '');
    final nameC = TextEditingController(text: cabang?.name ?? '');
    final addressC = TextEditingController(text: cabang?.address ?? '');
    final phoneC = TextEditingController(text: cabang?.phone ?? '');
    final kotaC = TextEditingController(text: cabang?.kota ?? '');
    final latLngC = TextEditingController(text: cabang?.latLngString ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(isEdit ? 'Edit Cabang' : 'Tambah Cabang'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: kodeC, decoration: const InputDecoration(labelText: 'Kode'), textCapitalization: TextCapitalization.characters),
              const SizedBox(height: 8),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Cabang')),
              const SizedBox(height: 8),
              TextField(controller: addressC, decoration: const InputDecoration(labelText: 'Alamat'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Kontak'), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: kotaC, decoration: const InputDecoration(labelText: 'Kota')),
              const SizedBox(height: 8),
              TextField(
                controller: latLngC,
                decoration: InputDecoration(
                  labelText: 'Latitude, Longitude',
                  hintText: '-6.234567, 106.891234',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (latLngC.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: latLngC.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tersalin'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.location_on_rounded, size: 20),
                        onPressed: () async {
                          double? lat, lng;
                          final parts = latLngC.text.trim().split(RegExp(r'\s*,\s*'));
                          if (parts.length == 2) {
                            lat = double.tryParse(parts[0]);
                            lng = double.tryParse(parts[1]);
                          }
                          final result = await LocationPicker.show(
                            context,
                            latitude: lat,
                            longitude: lng,
                          );
                          if (result != null) {
                            latLngC.text = '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              try {
                double? lat, lng;
                final parts = latLngC.text.trim().split(RegExp(r'\s*,\s*'));
                if (parts.length == 2) {
                  lat = double.tryParse(parts[0]);
                  lng = double.tryParse(parts[1]);
                }
                final data = <String, dynamic>{
                  'kode': kodeC.text.toUpperCase(),
                  'name': nameC.text,
                  'address': addressC.text,
                  'phone': phoneC.text,
                  'kota': kotaC.text,
                  if (lat != null && lng != null) ...{
                    'latitude': lat,
                    'longitude': lng,
                  },
                };
                if (isEdit) {
                  await ApiService().put('/cabangs/${cabang.id}', data: data);
                } else {
                  await ApiService().post('/cabangs', data: data);
                }
                Navigator.pop(ctx);
                ref.invalidate(_cabangsProvider);
                SoundPlayer.instance.playSuccess();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Cabang berhasil diperbarui' : 'Cabang berhasil ditambahkan'), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Error') : 'Error';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            child: Text(isEdit ? 'Simpan' : 'Tambah'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Cabang cabang) {
    final isActive = cabang.isActive;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(isActive ? 'Nonaktifkan Cabang' : 'Aktifkan Cabang'),
        content: Text(isActive
            ? 'Yakin nonaktifkan cabang "${cabang.kode} - ${cabang.name}"?'
            : 'Aktifkan kembali cabang "${cabang.kode} - ${cabang.name}"?'),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.red : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  try {
                    if (isActive) {
                      await ApiService().delete('/cabangs/${cabang.id}');
                    } else {
                      await ApiService().put('/cabangs/${cabang.id}', data: {'is_active': true});
                    }
                    Navigator.pop(ctx);
                    ref.invalidate(_cabangsProvider);
                    SoundPlayer.instance.playSuccess();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(isActive ? 'Cabang "${cabang.kode}" dinonaktifkan' : 'Cabang "${cabang.kode}" diaktifkan'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    Navigator.pop(ctx);
                    final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Gagal') : 'Gagal';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                child: Text(isActive ? 'NONAKTIFKAN' : 'AKTIFKAN'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
