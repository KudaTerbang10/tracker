import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../data/models/manifest.dart';
import '../providers/manifest_provider.dart';

class ManifestListScreen extends ConsumerStatefulWidget {
  const ManifestListScreen({super.key});
  @override
  ConsumerState<ManifestListScreen> createState() =>
      _ManifestListScreenState();
}

class _ManifestListScreenState extends ConsumerState<ManifestListScreen> {
  String? _selectedStatus;
  final _statuses = <String?>[null, 'dibuat', 'dalam_perjalanan', 'selesai'];
  final _statusLabels = <String?>[
    'Semua',
    'Dibuat',
    'Dalam Perjalanan',
    'Selesai',
  ];
  final _scrollController = ScrollController();
  int _page = 1;
  final _allManifests = <Manifest>[];
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    final nextPage = _page + 1;
    try {
      final filter = ManifestFilter(
        status: _selectedStatus,
        page: nextPage,
      );
      final data = await ref.read(manifestListProvider(filter).future);
      if (data.manifests.isEmpty) {
        _hasMore = false;
      } else {
        _allManifests.addAll(data.manifests);
        _page = nextPage;
        if (data.manifests.length < 20) _hasMore = false;
      }
      if (mounted) setState(() {});
    } finally {
      _loadingMore = false;
    }
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status;
      _page = 1;
      _allManifests.clear();
      _hasMore = true;
    });
    ref.invalidate(manifestListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ManifestFilter(status: _selectedStatus, page: _page);
    final async = ref.watch(manifestListProvider(filter));

    // Sync data from async to _allManifests
    async.whenData((data) {
      if (_allManifests.isEmpty && data.manifests.isNotEmpty) {
        _allManifests.addAll(data.manifests);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Daftar Manifest'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Status filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_statuses.length, (i) {
                  final isSelected = _selectedStatus == _statuses[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_statusLabels[i]!),
                      selected: isSelected,
                      onSelected: (_) => _onStatusChanged(_statuses[i]),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                      checkmarkColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primary
                            : const Color(0xFF64748B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // List
          Expanded(
            child: async.when(
              loading: () => _allManifests.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => _allManifests.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Belum ada manifest',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _allManifests.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _allManifests.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _ManifestCard(manifest: _allManifests[i]);
      },
    );
  }
}

class _ManifestCard extends ConsumerWidget {
  final Manifest manifest;
  const _ManifestCard({required this.manifest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd/MM/yy HH:mm', 'id_ID');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: manifest.isAntarCabang
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.description_rounded,
            size: 20,
            color: manifest.isAntarCabang ? AppTheme.primary : Colors.orange,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    manifest.noManifest,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                _badge(
                  manifest.tipeLabel,
                  manifest.isAntarCabang ? AppTheme.primary : Colors.orange,
                ),
                const SizedBox(width: 6),
                _badge(
                  '${manifest.workUnit} Work',
                  Colors.green,
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/dashboard/manifest/${manifest.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.print_rounded, size: 16, color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 12,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    manifest.driverName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusBadge(manifest.statusLabel, manifest.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  manifest.isAntarCabang
                      ? Icons.store_rounded
                      : Icons.location_on_rounded,
                  size: 12,
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${manifest.asalCabangName} → ${manifest.tujuanNama}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${manifest.totalResi} resi',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Summary row
          Row(
            children: [
              _statItem('Total Resi', '${manifest.totalResi}'),
              _statItem('Work Unit', '${manifest.workUnit}'),
              _statItem(
                'Dibuat',
                fmt.format(toJakarta(manifest.createdAt)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.push('/dashboard/manifest/${manifest.id}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Lihat Detail'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _statusBadge(String label, String status) {
    Color color;
    switch (status) {
      case 'dibuat':
        color = const Color(0xFFF59E0B);
        break;
      case 'dalam_perjalanan':
        color = AppTheme.primary;
        break;
      case 'selesai':
        color = Colors.green;
        break;
      default:
        color = const Color(0xFF94A3B8);
    }
    return _badge(label, color);
  }

  Widget _statItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
