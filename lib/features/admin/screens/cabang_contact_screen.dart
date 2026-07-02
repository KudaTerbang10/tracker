import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/datasources/local/hive_cache.dart';

class CabangContact {
  final String kode;
  final String name;
  final String address;
  final String phone;
  final String kota;
  final bool isActive;

  CabangContact({required this.kode, required this.name, required this.address, required this.phone, required this.kota, this.isActive = true});

  factory CabangContact.fromJson(Map<String, dynamic> json) {
    return CabangContact(
      kode: json['kode'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      kota: json['kota'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

final _cabangContactsProvider = FutureProvider.autoDispose<List<CabangContact>>((ref) async {
  final data = HiveCache.getCabangs();
  return data
      .map((e) => CabangContact.fromJson(e))
      .where((c) => c.isActive && c.kota.isNotEmpty && c.phone.isNotEmpty)
      .toList();
});

class CabangContactScreen extends ConsumerStatefulWidget {
  const CabangContactScreen({super.key});
  @override
  ConsumerState<CabangContactScreen> createState() => _CabangContactScreenState();
}

class _CabangContactScreenState extends ConsumerState<CabangContactScreen> {
  final _searchC = TextEditingController();
  String _search = '';
  String _kotaFilter = 'all';

  List<Map<String, String>> _buildFilters(List<CabangContact> cabangs) {
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
    return filters;
  }

  bool _matchKotaFilter(CabangContact c, String filter) {
    if (filter == 'all') return true;
    if (filter == 'jakarta') return c.kota.startsWith('Jakarta');
    return c.kota == filter;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_cabangContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Kontak Cabang'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
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
                  'jakarta': cabangs.where((c) => c.kota.startsWith('Jakarta')).length,
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
                }).where((c) => _matchKotaFilter(c, _kotaFilter)).toList();

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
                                final formattedPhone = c.phone.startsWith('08')
                                    ? c.phone.replaceAllMapped(
                                        RegExp(r'(\d{4})(\d{4})(\d+)'),
                                        (m) => '${m[1]}-${m[2]}-${m[3]}',
                                      )
                                    : c.phone;
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                          radius: 24,
                                          child: const Icon(Icons.business_rounded, color: Color(0xFF3B82F6), size: 22),
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
                                                  Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                                                  const SizedBox(width: 3),
                                                  Flexible(child: Text(c.kota, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade400),
                                                  const SizedBox(width: 3),
                                                  Flexible(child: Text(formattedPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 18, color: Color(0xFF4F46E5)),
                                          tooltip: 'Salin nomor',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: c.phone));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Nomor telepon tersalin'),
                                                duration: Duration(seconds: 1),
                                                backgroundColor: Color(0xFF10B981),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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
}
